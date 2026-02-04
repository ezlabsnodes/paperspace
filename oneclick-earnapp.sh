#!/bin/bash

# --- INPUT PROXY MANUAL ---
echo "======================================================="
echo " Silakan masukkan Proxy dengan format:"
echo " IP:PORT:USERNAME:PASSWORD"
echo "======================================================="
read -p "Masukkan Proxy: " PROXY_INPUT

# Memisahkan input berdasarkan delimiter titik dua (:)
IFS=':' read -r PROXY_IP PROXY_PORT PROXY_USER PROXY_PASS <<< "$PROXY_INPUT"

# Validasi input sederhana
if [[ -z "$PROXY_IP" || -z "$PROXY_PORT" || -z "$PROXY_USER" || -z "$PROXY_PASS" ]]; then
    echo "Error: Format input salah atau ada bagian yang kosong."
    echo "Pastikan formatnya adalah IP:PORT:USER:PASS"
    exit 1
fi

echo "Proxy terdeteksi:"
echo "IP: $PROXY_IP"
echo "Port: $PROXY_PORT"
echo "User: $PROXY_USER"
echo "-------------------------------------------------------"

echo "=== 1. SYSTEM UPDATE & INSTALLING DEPENDENCIES ==="
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
sudo apt install proxychains4 -y

echo "=== 2. CONFIGURING PROXYCHAINS ==="
sudo bash -c "cat > /etc/proxychains4.conf <<EOF
dynamic_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 45000
tcp_connect_time_out 30000

[ProxyList]
http $PROXY_IP $PROXY_PORT $PROXY_USER $PROXY_PASS
EOF"

echo "=== 3. INSTALLING EARNAPP (AUTO-YES) ==="
# Download script
wget -qO- https://brightdata.com/static/earnapp/install.sh > /tmp/earnapp.sh

# Auto-agree license dengan pipe 'yes'
echo "yes" | sudo bash /tmp/earnapp.sh

echo "=== 4. CONFIGURING SERVICES ==="
# Stop dan disable service bawaan
sudo systemctl stop earnapp
sudo systemctl disable earnapp
sudo systemctl stop earnapp_upgrader
sudo systemctl disable earnapp_upgrader

# Hapus upgrader agar tidak konflik
sudo rm -f /etc/systemd/system/earnapp_upgrader.service
sudo rm -f /lib/systemd/system/earnapp_upgrader.service
sudo systemctl daemon-reload

# Buat Service Proxy Baru
sudo bash -c 'cat > /etc/systemd/system/earnapp-proxy.service <<EOT
[Unit]
Description=EarnApp through Proxychains
After=network.target

[Service]
ExecStart=/usr/bin/proxychains4 /usr/bin/earnapp run
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOT'

echo "=== 5. SETTING UP AUTO-RESTART CRONJOB (EVERY 6 HOURS) ==="
# Mencari path systemctl untuk memastikan cron berjalan lancar
SYSTEMCTL_PATH=$(which systemctl)

# Membuat file cron khusus di /etc/cron.d/ agar permanen dan rapi
# Format: Menit Jam Tanggal Bulan Hari User Command
sudo bash -c "cat > /etc/cron.d/earnapp-autorestart <<EOF
0 */6 * * * root $SYSTEMCTL_PATH restart earnapp-proxy
EOF"

# Set permission yang benar
sudo chmod 644 /etc/cron.d/earnapp-autorestart
echo "Cronjob berhasil dibuat: Service akan restart otomatis setiap 6 jam."

echo "=== 6. STARTING EARNAPP PROXY SERVICE ==="
sudo systemctl daemon-reload
sudo systemctl enable earnapp-proxy
sudo systemctl start earnapp-proxy

echo "=== SETUP COMPLETE! ==="
echo "Waiting for the service to initialize..."
sleep 5
echo "---------------------------------------------"
echo "Please copy the URL below to link your device:"
echo "---------------------------------------------"
sudo proxychains4 earnapp showid
echo "---------------------------------------------"
echo "Log Status: sudo systemctl status earnapp-proxy"
echo "Cek Cron: cat /etc/cron.d/earnapp-autorestart"
