
# Prompt for local IP
read -p "Enter the local IP (default: 10.144.144.1): " LOCAL_IP
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="10.144.144.1"
fi

# Prompt for encryption password
read -p "Enter the encryption password (default: 1qaz2wsx66): " ENC_PASSWORD
if [ -z "$ENC_PASSWORD" ]; then
    ENC_PASSWORD="1qaz2wsx66"
fi

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
-L=tcp://:8097/10.144.144.105:8097 \
-L=tcp://:8051/10.144.144.106:8051 \
-L=tcp://:2053/10.144.144.106:2053 \
-L=tcp://:8321/10.144.144.111:8321 \
-L=tcp://:8096/10.144.144.112:8096 \
-L=tcp://:8086/10.144.144.113:8086 \
-L=tcp://:8088/10.144.144.114:8088 \
-L=tcp://:8098/10.144.144.115:8098 \
-L=tcp://:8452/10.144.144.126:8452 \
-L=tcp://:8764/10.144.144.136:8764 \
-L=tcp://:8765/10.144.144.137:8765 \
-L=tcp://:8099/10.144.144.138:8099 \
-L=tcp://:8220/10.144.144.139:8220 \
-L=tcp://:8091/10.144.144.140:8091 \
-L=tcp://:8052/10.144.144.107:8052 \
-L=tcp://:8087/10.144.144.135:8087 \
-L=tcp://:8095/10.144.144.141:8095 \
-L=tcp://:8089/10.144.144.142:8089 \
-L=tcp://:9501/10.144.144.202:9501 \
-L=tcp://:2087/10.144.144.202:2087 \
-L=tcp://:9502/10.144.144.203:9502 \
-L=tcp://:9503/10.144.144.204:9503 \
-L=tcp://:9504/10.144.144.205:9504 \
-L=tcp://:9505/10.144.144.206:9505 \
-L=tcp://:8085/10.144.144.220:8085 \
-L=tcp://:8937/10.144.144.222:8937 \
-L=tcp://:41431/10.144.144.223:41431 \
-L=tcp://:8629/10.144.144.221:8629 \
-L=tcp://:2244/10.144.144.224:2244 \
-L=tcp://:35800/10.144.144.224:35800 \
-L=tcp://:2250/10.144.144.225:2250 \
-L=tcp://:36800/10.144.144.225:36800

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
peers:
  - "188.245.205.192"
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
