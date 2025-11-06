#!/bin/bash
# Install Kerberos CLI tool

echo "Installing Kerberos CLI tool..."

# Copy the CLI script to /usr/local/bin
cp /home/ubuntu/kerberos-cli.sh /usr/local/bin/kerberos
chmod +x /usr/local/bin/kerberos

echo "Kerberos CLI installed successfully!"
echo "Usage: kerberos [command]"
echo "Run 'kerberos help' for more information"