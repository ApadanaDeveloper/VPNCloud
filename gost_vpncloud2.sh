#!/usr/bin/env bash

# Prompt for local IP address
read -p "Enter the local IP (default: 10.144.144.1): " LOCAL_IP
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="10.144.144.1"
fi

# Prompt for encryption password
read -p "Enter the encryption password (default: 123456): " ENC_PASSWORD
if [ -z "$ENC_PASSWORD" ]; then
    ENC_PASSWORD="123456"
fi

# Prompt for peer IP addresses
echo "Enter the IP addresses of peers, one per line. Type 'done' when finished:"
PEERS=()
while true; do
    read -p "Peer IP: " PEER_IP
    if [[ "$PEER_IP" == "done" ]]; then
        break
    elif [[ "$PEER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        PEERS+=("$PEER_IP")
    else
        echo "Invalid IP address. Please try again."
    fi
done

# Update package lists and install required packages
sudo apt-get update -y
sudo apt-get install wget nano -y

# Download and decompress gost binary
wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
gunzip gost-linux-amd64-2.11.5.gz

# Move binary to /usr/local/bin and make executable
sudo mv gost-linux-amd64-2.11.5 /usr/local/bin/gost
sudo chmod +x /usr/local/bin/gost

# Create systemd service file
sudo bash -c 'cat > /usr/lib/systemd/system/gost.service <<EOF
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost \
-L=tcp://:8050/10.144.144.102:8050 \
# Add more gost tunnels here if needed

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd units
sudo systemctl daemon-reload

# Enable and start gost service
sudo systemctl enable gost
sudo systemctl start gost

echo "GOST installation and service setup complete."
echo "Let's install VPNCLOUD."

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Variables
VPNCLOUD_URL="https://github.com/dswd/vpncloud/releases/download/v2.3.0/vpncloud_2.3.0_amd64.deb"
CONFIG_DIR="/etc/vpncloud"
CONFIG_FILE="$CONFIG_DIR/musix.net"
SERVICE_FILE="/lib/systemd/system/vpncloud@.service"

# Update and install dependencies
apt-get update -y
apt-get install -y curl

# Download and install vpncloud
TMP_DEB="/tmp/vpncloud.deb"
curl -sSL -o "$TMP_DEB" "$VPNCLOUD_URL"
dpkg -i "$TMP_DEB" || apt-get install -f -y
rm -f "$TMP_DEB"

# Ensure configuration directory exists
mkdir -p "$CONFIG_DIR"

# Convert the array of peers into YAML format
PEER_LIST=""
for PEER in "${PEERS[@]}"; do
    PEER_LIST="$PEER_LIST\n  - \"$PEER\""
done

# Create the configuration file using the user-provided LOCAL_IP and ENC_PASSWORD
cat > "$CONFIG_FILE" <<EOF
device:
  type: tap
  name: vpncloud%d
  path: ~
  fix-rp-filter: false
ip: $LOCAL_IP
advertise-addresses: []
ifup: ~
ifdown: ~
crypto:
  password: "$ENC_PASSWORD"
  private-key: ~
  public-key: ~
  trusted-keys: []
  algorithms:
    - PLAIN
listen: "3210"
peers:$PEER_LIST
peer-timeout: 300
keepalive: ~
beacon:
  store: ~
  load: ~
  interval: 3600
  password: ~
mode: normal
switch-timeout: 300
claims: []
auto-claim: true
port-forwarding: true
pid-file: ~
stats-file: ~
statsd:
  server: ~
  prefix: ~
user: ~
group: ~
hook: ~
hooks: {}
EOF

# Create systemd template service if it doesn't exist (usually already included)
if [ ! -f "$SERVICE_FILE" ]; then
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=VPN Cloud instance %i
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/vpncloud --config /etc/vpncloud/%i.net
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
fi

# Reload systemd units
systemctl daemon-reload

# Enable and start the vpncloud@musix service
systemctl enable vpncloud@musix
systemctl start vpncloud@musix

# Show service status
systemctl status vpncloud@musix --no-pager
