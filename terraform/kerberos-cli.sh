#!/bin/bash

# Kerberos.io MicroK8s Management CLI
# This script provides helpful commands for managing your Kerberos.io deployment

# sudo tail -f /var/log/user-data.log
# cat /home/ubuntu/ACCESS_INFO.txt
# microk8s kubectl get pods -A
# microk8s kubectl describe pod hub-api-588c6bcb74-wqvrl -n kerberos-hub

VERSION="1.0.0"
SCRIPT_NAME="kerberos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Show help
show_help() {
    cat << EOF
${BLUE}Kerberos.io MicroK8s Management CLI v${VERSION}${NC}

Usage: $SCRIPT_NAME [COMMAND]

${GREEN}Status Commands:${NC}
  status              Show overall system status
  pods                List all pods across all namespaces
  pods-vault          List Kerberos Vault pods
  pods-factory        List Kerberos Factory pods
  pods-hub            List Kerberos Hub pods
  pods-minio          List MinIO pods
  pods-mongodb        List MongoDB pods
  pods-rabbitmq       List RabbitMQ pods
  services            List all services
  nodes               Show node resource usage

${GREEN}Diagnostic Commands:${NC}
  diagnose            Run full system diagnostics
  events              Show recent cluster events
  logs <pod> <ns>     Show logs for a specific pod
  describe <pod> <ns> Describe a specific pod
  check-ports         Check if service ports are listening
  test-services       Test HTTP connectivity to services

${GREEN}Management Commands:${NC}
  restart-vault       Restart Kerberos Vault pods
  restart-factory     Restart Kerberos Factory pods
  restart-hub         Restart Kerberos Hub pods
  restart-mongodb     Restart MongoDB
  restart-rabbitmq    Restart RabbitMQ
  restart-all         Restart all Kerberos.io services
  scale-hub <n>       Scale Hub deployments to n replicas

${GREEN}Information Commands:${NC}
  info                Show deployment information and URLs
  access              Show ACCESS_INFO.txt file
  ip                  Show instance public IP
  urls                Show service URLs
  credentials         Show default credentials

${GREEN}Troubleshooting Commands:${NC}
  fix-images          Restart containerd and retry failed image pulls
  fix-storage         Check and fix storage issues
  fix-minio           Reinstall MinIO operator and tenant
  cleanup-failed      Delete all failed/pending pods

${GREEN}Utility Commands:${NC}
  version             Show CLI version
  help                Show this help message

${YELLOW}Examples:${NC}
  $SCRIPT_NAME status                    # Show overall status
  $SCRIPT_NAME logs vault-xxx kerberos-vault  # Show vault logs
  $SCRIPT_NAME restart-hub               # Restart Hub services
  $SCRIPT_NAME diagnose                  # Run full diagnostics

${YELLOW}Quick Diagnostics:${NC}
  If services aren't working:
    1. Run: $SCRIPT_NAME diagnose
    2. Check: $SCRIPT_NAME pods
    3. Fix: $SCRIPT_NAME fix-images (if image pull errors)
    4. Restart: $SCRIPT_NAME restart-all

For more information, visit: https://doc.kerberos.io/
EOF
}

# Status commands
cmd_status() {
    print_header "Kerberos.io System Status"
    
    echo ""
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    INSTANCE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    echo "Instance IP: $INSTANCE_IP"

    echo ""
    print_header "Pod Status Summary"
    local running=$(microk8s kubectl get pods -A --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    local pending=$(microk8s kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    local failed=$(microk8s kubectl get pods -A --field-selector=status.phase=Failed --no-headers 2>/dev/null | wc -l)
    
    echo -e "${GREEN}Running:${NC} $running"
    echo -e "${YELLOW}Pending:${NC} $pending"
    echo -e "${RED}Failed:${NC} $failed"
    
    echo ""
    print_header "Node Resources"
    microk8s kubectl top node 2>/dev/null || echo "Metrics not available"
    
    echo ""
    print_header "Service Status"
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    local ip=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    for port in 30080 30081 32080 30900; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port 2>/dev/null | grep -q "200\|301\|302\|401"; then
            print_success "Port $port is responding"
        else
            print_error "Port $port is not responding"
        fi
    done
}

cmd_pods() {
    print_header "All Pods"
    microk8s kubectl get pods -A
}

cmd_pods_vault() {
    print_header "Kerberos Vault Pods"
    microk8s kubectl get pods -n kerberos-vault
}

cmd_pods_factory() {
    print_header "Kerberos Factory Pods"
    microk8s kubectl get pods -n kerberos-factory
}

cmd_pods_hub() {
    print_header "Kerberos Hub Pods"
    microk8s kubectl get pods -n kerberos-hub
}

cmd_pods_minio() {
    print_header "MinIO Pods"
    microk8s kubectl get pods -n minio-tenant
    microk8s kubectl get pods -n minio-operator
}

cmd_pods_mongodb() {
    print_header "MongoDB Pods"
    microk8s kubectl get pods -n mongodb
}

cmd_pods_rabbitmq() {
    print_header "RabbitMQ Pods"
    microk8s kubectl get pods -n rabbitmq
}

cmd_services() {
    print_header "All Services"
    microk8s kubectl get svc -A
}

cmd_nodes() {
    print_header "Node Resource Usage"
    microk8s kubectl top node
    echo ""
    microk8s kubectl describe node | grep -A 5 "Allocated resources"
}

# Diagnostic commands
cmd_diagnose() {
    print_header "Running Full System Diagnostics"
    
    echo ""
    print_header "1. Checking MicroK8s Status"
    microk8s status
    
    echo ""
    print_header "2. Checking Pod Status"
    cmd_status
    
    echo ""
    print_header "3. Checking Non-Running Pods"
    microk8s kubectl get pods -A | grep -v "Running\|Completed" || echo "All pods are running!"
    
    echo ""
    print_header "4. Recent Events (Last 20)"
    microk8s kubectl get events -A --sort-by='.lastTimestamp' | tail -20
    
    echo ""
    print_header "5. Storage Status"
    echo "Storage Classes:"
    microk8s kubectl get sc
    echo ""
    echo "Persistent Volume Claims:"
    microk8s kubectl get pvc -A
    
    echo ""
    print_header "6. Service Connectivity"
    cmd_check_ports
    
    echo ""
    print_header "Diagnostics Complete"
    echo "If you see issues, try:"
    echo "  - $SCRIPT_NAME fix-images (for image pull errors)"
    echo "  - $SCRIPT_NAME restart-all (to restart services)"
    echo "  - $SCRIPT_NAME cleanup-failed (to remove failed pods)"
}

cmd_events() {
    print_header "Recent Cluster Events"
    microk8s kubectl get events -A --sort-by='.lastTimestamp' | tail -30
}

cmd_logs() {
    if [ -z "$2" ] || [ -z "$3" ]; then
        print_error "Usage: $SCRIPT_NAME logs <pod-name> <namespace>"
        exit 1
    fi
    print_header "Logs for $2 in namespace $3"
    microk8s kubectl logs -f "$2" -n "$3"
}

cmd_describe() {
    if [ -z "$2" ] || [ -z "$3" ]; then
        print_error "Usage: $SCRIPT_NAME describe <pod-name> <namespace>"
        exit 1
    fi
    print_header "Describing $2 in namespace $3"
    microk8s kubectl describe pod "$2" -n "$3"
}

cmd_check_ports() {
    print_header "Checking Service Ports"
    for port in 30080 30081 32080 30900; do
        if sudo ss -tlnp | grep -q ":$port "; then
            print_success "Port $port is listening"
        else
            print_warning "Port $port is not listening"
        fi
    done
}

cmd_test_services() {
    print_header "Testing Service Connectivity"
    local services=("30080:Vault" "30081:Factory" "32080:Hub" "30900:MinIO")
    
    for service in "${services[@]}"; do
        IFS=':' read -r port name <<< "$service"
        local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port 2>/dev/null)
        if [ "$response" = "200" ] || [ "$response" = "301" ] || [ "$response" = "302" ] || [ "$response" = "401" ]; then
            print_success "$name (port $port): HTTP $response"
        else
            print_error "$name (port $port): Not responding"
        fi
    done
}

# Management commands
cmd_restart_vault() {
    print_header "Restarting Kerberos Vault"
    microk8s kubectl delete pod -n kerberos-vault --all
    print_success "Vault pods deleted, they will restart automatically"
}

cmd_restart_factory() {
    print_header "Restarting Kerberos Factory"
    microk8s kubectl delete pod -n kerberos-factory --all
    print_success "Factory pods deleted, they will restart automatically"
}

cmd_restart_hub() {
    print_header "Restarting Kerberos Hub"
    microk8s kubectl delete pod -n kerberos-hub --all
    print_success "Hub pods deleted, they will restart automatically"
}

cmd_restart_mongodb() {
    print_header "Restarting MongoDB"
    microk8s kubectl delete pod -n mongodb --all
    print_success "MongoDB pods deleted, they will restart automatically"
}

cmd_restart_rabbitmq() {
    print_header "Restarting RabbitMQ"
    microk8s kubectl delete pod -n rabbitmq --all
    print_success "RabbitMQ pods deleted, they will restart automatically"
}

cmd_restart_all() {
    print_header "Restarting All Kerberos.io Services"
    cmd_restart_vault
    cmd_restart_factory
    cmd_restart_hub
    print_success "All services restarted"
}

cmd_scale_hub() {
    if [ -z "$2" ]; then
        print_error "Usage: $SCRIPT_NAME scale-hub <replicas>"
        exit 1
    fi
    print_header "Scaling Hub Deployments to $2 Replicas"
    microk8s kubectl scale deployment --replicas="$2" -n kerberos-hub --all
    print_success "Hub scaled to $2 replicas"
}

# Information commands
cmd_info() {
    print_header "Kerberos.io Deployment Information"
    cat /home/ubuntu/ACCESS_INFO.txt 2>/dev/null || print_error "ACCESS_INFO.txt not found"
}

cmd_access() {
    cmd_info
}

cmd_ip() {    
    # Get a token first
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    # Use the token to get IP
    local ip=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
    print_header "Instance Public IP"
    echo "Instance IP: $ip"
    echo "$ip"
}

cmd_urls() {
    local ip=$(cmd_ip)
    print_header "Service URLs"
    echo "Kerberos Vault:   http://$ip:30080"
    echo "Kerberos Factory: http://$ip:30081"
    echo "Kerberos Hub:     http://$ip:32080"
    echo "MinIO Console:    http://$ip:30900"
}

cmd_credentials() {
    print_header "Default Credentials"
    grep -A 20 "Default Credentials:" /home/ubuntu/ACCESS_INFO.txt 2>/dev/null || print_error "Credentials not found in ACCESS_INFO.txt"
}

# Troubleshooting commands
cmd_fix_images() {
    print_header "Fixing Image Pull Issues"
    print_warning "Restarting containerd..."
    sudo systemctl restart snap.microk8s.daemon-containerd
    sleep 10
    print_success "Containerd restarted"
    
    print_warning "Deleting failed pods..."
    microk8s kubectl delete pod -n mongodb --field-selector=status.phase!=Running
    microk8s kubectl delete pod -n rabbitmq --field-selector=status.phase!=Running
    microk8s kubectl delete pod -n kerberos-vault --field-selector=status.phase!=Running
    microk8s kubectl delete pod -n kerberos-hub --field-selector=status.phase!=Running
    
    print_success "Failed pods deleted, they will restart and retry image pulls"
}

cmd_fix_storage() {
    print_header "Checking Storage"
    echo "Storage Classes:"
    microk8s kubectl get sc
    echo ""
    echo "PVCs:"
    microk8s kubectl get pvc -A
    echo ""
    echo "Disk Usage:"
    df -h /media/storage
}

cmd_fix_minio() {
    print_header "Reinstalling MinIO"
    
    print_warning "Removing existing MinIO installation..."
    microk8s kubectl delete -k /home/ubuntu/deployment/operator/ 2>/dev/null || true
    microk8s kubectl delete -f /home/ubuntu/deployment/base/minio/minio-tenant-base.yaml 2>/dev/null || true
    
    sleep 5
    
    print_warning "Installing MinIO operator..."
    cd /home/ubuntu/deployment
    if [ ! -d "operator" ]; then
        git clone --depth 1 --branch v6.0.1 https://github.com/minio/operator.git
    fi
    microk8s kubectl apply -k operator/
    
    print_warning "Waiting for operator..."
    sleep 30
    microk8s kubectl scale deployment minio-operator -n minio-operator --replicas=1
    
    print_warning "Deploying MinIO tenant..."
    microk8s kubectl apply -f base/minio/minio-tenant-base.yaml
    
    print_success "MinIO reinstallation initiated"
    echo "Wait a few minutes, then check: $SCRIPT_NAME pods-minio"
}

cmd_cleanup_failed() {
    print_header "Cleaning Up Failed/Pending Pods"
    microk8s kubectl delete pod -A --field-selector=status.phase=Failed
    microk8s kubectl delete pod -A --field-selector=status.phase=Pending
    print_success "Failed and pending pods deleted"
}

# Main command router
case "${1:-help}" in
    # Status commands
    status) cmd_status ;;
    pods) cmd_pods ;;
    pods-vault) cmd_pods_vault ;;
    pods-factory) cmd_pods_factory ;;
    pods-hub) cmd_pods_hub ;;
    pods-minio) cmd_pods_minio ;;
    pods-mongodb) cmd_pods_mongodb ;;
    pods-rabbitmq) cmd_pods_rabbitmq ;;
    services) cmd_services ;;
    nodes) cmd_nodes ;;
    
    # Diagnostic commands
    diagnose) cmd_diagnose ;;
    events) cmd_events ;;
    logs) cmd_logs "$@" ;;
    describe) cmd_describe "$@" ;;
    check-ports) cmd_check_ports ;;
    test-services) cmd_test_services ;;
    
    # Management commands
    restart-vault) cmd_restart_vault ;;
    restart-factory) cmd_restart_factory ;;
    restart-hub) cmd_restart_hub ;;
    restart-mongodb) cmd_restart_mongodb ;;
    restart-rabbitmq) cmd_restart_rabbitmq ;;
    restart-all) cmd_restart_all ;;
    scale-hub) cmd_scale_hub "$@" ;;
    
    # Information commands
    info) cmd_info ;;
    access) cmd_access ;;
    ip) cmd_ip ;;
    urls) cmd_urls ;;
    credentials) cmd_credentials ;;
    
    # Troubleshooting commands
    fix-images) cmd_fix_images ;;
    fix-storage) cmd_fix_storage ;;
    fix-minio) cmd_fix_minio ;;
    cleanup-failed) cmd_cleanup_failed ;;
    
    # Utility commands
    version) echo "Kerberos.io CLI v${VERSION}" ;;
    help|--help|-h) show_help ;;
    
    *)
        print_error "Unknown command: $1"
        echo "Run '$SCRIPT_NAME help' for usage information"
        exit 1
        ;;
esac