#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Kerberos.io MicroK8s deployment ==="
echo "Timestamp: $(date)"

# Create Kerberos CLI tool
echo "=== Creating Kerberos CLI tool ==="
cat > /usr/local/bin/kerberos <<'EOFCLI'
#!/bin/bash
# Kerberos.io MicroK8s Management CLI - See full content in terraform/kerberos-cli.sh
# This is a placeholder - the full script will be copied during deployment
echo "Kerberos CLI not yet installed. Run: sudo /home/ubuntu/install-kerberos-cli.sh"
EOFCLI

chmod +x /usr/local/bin/kerberos

# Update system
echo "=== Updating system packages ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install required packages
echo "=== Installing required packages ==="
apt-get install -y \
    snapd \
    git \
    curl \
    wget \
    jq \
    unzip \
    coturn

# Format and mount storage volume
echo "=== Setting up storage volume ==="
STORAGE_DEVICE="${storage_device}"
STORAGE_PATH="${storage_path}"

# Wait for device to be available
while [ ! -e "$STORAGE_DEVICE" ]; do
    echo "Waiting for storage device $STORAGE_DEVICE..."
    sleep 5
done

# Check if device is already formatted
if ! blkid "$STORAGE_DEVICE"; then
    echo "Formatting storage device..."
    mkfs.ext4 -F "$STORAGE_DEVICE"
fi

# Create mount point and mount
mkdir -p "$STORAGE_PATH"
mount "$STORAGE_DEVICE" "$STORAGE_PATH"

# Add to fstab for persistence
DEVICE_UUID=$(blkid -s UUID -o value "$STORAGE_DEVICE")
if ! grep -q "$DEVICE_UUID" /etc/fstab; then
    echo "UUID=$DEVICE_UUID $STORAGE_PATH ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Set permissions
chmod 755 "$STORAGE_PATH"

# Install MicroK8s
echo "=== Installing MicroK8s ==="
snap install microk8s --classic --channel=1.32/stable

# Add ubuntu user to microk8s group
usermod -a -G microk8s ubuntu
chown -f -R ubuntu ~/.kube || true

# Create kubectl and helm aliases
snap alias microk8s.kubectl kubectl
snap alias microk8s.helm helm

# Wait for MicroK8s to be ready
echo "=== Waiting for MicroK8s to be ready ==="
microk8s status --wait-ready

# Enable required addons
echo "=== Enabling MicroK8s addons ==="
microk8s enable dns
microk8s enable dashboard
microk8s enable hostpath-storage

# Enable NVIDIA support if GPU is available
if lspci | grep -i nvidia > /dev/null; then
    echo "NVIDIA GPU detected, enabling GPU support..."
    microk8s enable nvidia
fi

# Configure coturn (TURN server)
echo "=== Configuring TURN server ==="
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

cat > /etc/turnserver.conf <<EOF
listening-port=8443
relay-ip=$INSTANCE_IP
fingerprint
lt-cred-mech
user=${turn_username}:${turn_password}
syslog
EOF

# Enable and start coturn
systemctl enable coturn
systemctl restart coturn

# Clone deployment repository
echo "=== Cloning Kerberos.io deployment repository ==="
cd /home/ubuntu
if [ ! -d "deployment" ]; then
    git clone https://github.com/whitslar/deployment
    chown -R ubuntu:ubuntu deployment
fi

cd deployment

# Wait a bit more for MicroK8s to stabilize
sleep 30

# Run the configure script
echo "=== Running Kerberos.io deployment ==="
chmod +x configure.sh

# Update the kustomization overlay with actual credentials
echo "=== Updating kustomization overlay with credentials ==="
sed -i "s/localhost/$INSTANCE_IP/g" overlays/microk8s/kustomization.yaml
sed -i "s/yourusername/${rabbitmq_username}/g" overlays/microk8s/kustomization.yaml
sed -i "s/yourpassword/${rabbitmq_password}/g" overlays/microk8s/kustomization.yaml
sed -i "s/username1/${turn_username}/g" overlays/microk8s/kustomization.yaml
sed -i "s/password1/${turn_password}/g" overlays/microk8s/kustomization.yaml

# Also update MongoDB password in the overlay
sed -i "s/password: \"yourpassword\"/password: \"${mongodb_password}\"/g" overlays/microk8s/kustomization.yaml

# Update MongoDB password in configmaps (for Vault and Factory)
sed -i "s/yourmongodbpassword/${mongodb_password}/g" base/vault/mongodb-configmap.yaml
sed -i "s/yourmongodbpassword/${mongodb_password}/g" base/factory/mongodb-configmap.yaml

# Update Vault credentials in deployment
sed -i "s/value: \"root\"/value: \"${vault_username}\"/g" base/vault/kerberos-vault-deployment.yaml
sed -i "s/value: \"kerberos\"/value: \"${vault_password}\"/g" base/vault/kerberos-vault-deployment.yaml

# Run deployment as ubuntu user
su - ubuntu -c "cd /home/ubuntu/deployment && ./configure.sh apply -s ${storage_path} -i $INSTANCE_IP"

# Wait for all pods to be ready
echo "=== Waiting for all pods to be ready (this may take 10-15 minutes) ==="
su - ubuntu -c "microk8s kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=900s" || true

# Create MinIO bucket
echo "=== Setting up MinIO bucket ==="
sleep 60  # Wait for MinIO to be fully ready

# Install MinIO client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o /usr/local/bin/mc
chmod +x /usr/local/bin/mc

# Port forward and create bucket
su - ubuntu -c "microk8s kubectl port-forward svc/myminio-hl 9000 -n minio-tenant &"
sleep 10

mc alias set myminio http://localhost:9000 ${minio_access_key} ${minio_secret_key} --insecure || true
mc mb myminio/mybucket --insecure || true

pkill -f "port-forward" || true

# Create deployment completion marker
echo "=== Deployment completed successfully ==="
date > /var/log/kerberos-deployment-complete.txt

# Print access information
cat > /home/ubuntu/ACCESS_INFO.txt <<EOF
=================================================================
Kerberos.io MicroK8s Deployment - Access Information
=================================================================

Instance IP: $INSTANCE_IP

Service URLs:
-------------
Kerberos Vault:   http://$INSTANCE_IP:30080
Kerberos Factory: http://$INSTANCE_IP:30081
Kerberos Hub:     http://$INSTANCE_IP:32080
MinIO Console:    http://$INSTANCE_IP:30900

Default Credentials:
-------------------
Vault:
  Username: ${vault_username}
  Password: ${vault_password}

MongoDB:
  Username: root
  Password: ${mongodb_password}

RabbitMQ:
  Username: ${rabbitmq_username}
  Password: ${rabbitmq_password}

MinIO:
  Access Key: ${minio_access_key}
  Secret Key: ${minio_secret_key}

TURN Server:
  Host: turn:$INSTANCE_IP:8443
  Username: ${turn_username}
  Password: ${turn_password}

Useful Commands:
---------------
Check pod status:
  microk8s kubectl get pods -A

View logs:
  microk8s kubectl logs -f <pod-name> -n <namespace>

Access MicroK8s dashboard:
  microk8s dashboard-proxy

Storage Path: ${storage_path}

=================================================================
EOF

chown ubuntu:ubuntu /home/ubuntu/ACCESS_INFO.txt

echo "=== User data script completed ==="
echo "Access information saved to /home/ubuntu/ACCESS_INFO.txt"