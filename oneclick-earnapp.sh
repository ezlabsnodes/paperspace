#!/bin/bash

# Pastikan dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo "Harap jalankan dengan sudo!" 
   exit 1
fi

# --- 1. INPUT PROXY MANUAL ---
echo "-------------------------------------------------------"
echo "Masukkan data proxy dengan format:"
echo "1. IP:PORT  (tanpa autentikasi)"
echo "2. IP:PORT:USER:PASS  (dengan autentikasi)"
read -p "Data Proxy: " RAW_PROXY

# Memecah input berdasarkan jumlah ":"
IFS=':' read -r -a PROXY_PARTS <<< "$RAW_PROXY"
PROXY_PARTS_COUNT=${#PROXY_PARTS[@]}

# Validasi dan parsing
if [[ $PROXY_PARTS_COUNT -eq 2 ]]; then
    # Format: IP:PORT (tanpa auth)
    PROXY_IP=${PROXY_PARTS[0]}
    PROXY_PORT=${PROXY_PARTS[1]}
    PROXY_USER=""
    PROXY_PASS=""
    echo "Proxy diset: $PROXY_IP:$PROXY_PORT (tanpa autentikasi)"
elif [[ $PROXY_PARTS_COUNT -eq 4 ]]; then
    # Format: IP:PORT:USER:PASS (dengan auth)
    PROXY_IP=${PROXY_PARTS[0]}
    PROXY_PORT=${PROXY_PARTS[1]}
    PROXY_USER=${PROXY_PARTS[2]}
    PROXY_PASS=${PROXY_PARTS[3]}
    echo "Proxy diset: $PROXY_USER@$PROXY_IP:$PROXY_PORT"
else
    echo "Format salah! Gunakan format:"
    echo "- IP:PORT  (tanpa autentikasi)"
    echo "- IP:PORT:USER:PASS  (dengan autentikasi)"
    exit 1
fi

echo "-------------------------------------------------------"

# Setup agar tidak ada prompt ungu (non-interactive)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "=== UPDATE SYSTEM ==="
apt-get update -y > /dev/null 2>&1

echo "=== INSTALLING PROXYCHAINS ==="
apt-get install -y proxychains4 > /dev/null 2>&1

echo "=== CONFIGURING PROXYCHAINS ==="
# Buat konfigurasi proxychains berdasarkan tipe proxy
if [[ -z "$PROXY_USER" ]]; then
    # Proxy tanpa autentikasi
    cat > /etc/proxychains4.conf <<EOF
dynamic_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 45000
tcp_connect_time_out 30000

[ProxyList]
http $PROXY_IP $PROXY_PORT
EOF
else
    # Proxy dengan autentikasi
    cat > /etc/proxychains4.conf <<EOF
dynamic_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 45000
tcp_connect_time_out 30000

[ProxyList]
http $PROXY_IP $PROXY_PORT $PROXY_USER $PROXY_PASS
EOF
fi

echo "=== INSTALLING EARNAPP ==="
wget -qO- https://brightdata.com/static/earnapp/install.sh > /tmp/earnapp.sh
chmod +x /tmp/earnapp.sh
INSTALL_OUTPUT=$(yes yes | bash /tmp/earnapp.sh 2>&1)

# Cari link dari output instalasi
EARN_LINK=$(echo "$INSTALL_OUTPUT" | grep -o "https://earnapp.com/r/sdk-node-[a-zA-Z0-9]*" | head -n1)

# Stop semua service earnapp
pkill -9 -f earnapp 2>/dev/null

echo "=== CONFIGURING SERVICES ==="
# Stop and disable the default services
systemctl stop earnapp earnapp_upgrader 2>/dev/null
systemctl disable earnapp earnapp_upgrader 2>/dev/null

# Remove upgrader service
rm -f /etc/systemd/system/earnapp_upgrader.service 2>/dev/null
rm -f /lib/systemd/system/earnapp_upgrader.service 2>/dev/null

# Create the new Proxy Service
cat > /etc/systemd/system/earnapp-proxy.service <<EOT
[Unit]
Description=EarnApp through Proxychains
After=network.target

[Service]
ExecStart=/usr/bin/proxychains4 /usr/bin/earnapp run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOT

echo "=== ADDING CRONJOB ==="
# Add cronjob to restart every 6 hours
(crontab -l 2>/dev/null | grep -v "earnapp-proxy"; echo "0 */6 * * * /usr/bin/systemctl restart earnapp-proxy") | crontab -

echo "=== STARTING SERVICE ==="
systemctl daemon-reload
systemctl enable earnapp-proxy
systemctl start earnapp-proxy

sleep 5

# Tampilkan output sederhana
echo ""
echo "======================================================="
if [ -n "$EARN_LINK" ]; then
    echo "Link: $EARN_LINK"
    echo "Status: ✓ Service aktif dengan proxy"
else
    echo "Link: (jalankan: systemctl status earnapp-proxy)"
    echo "Status: ✓ Service aktif dengan proxy"
fi
echo "======================================================="
