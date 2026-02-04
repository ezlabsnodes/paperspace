#!/bin/bash
# 1. Auto Sudo
if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

echo "=== MEMULAI SETUP (ULTRA FAST) ==="

# 2. Generate & Set Password (INSTANT)
ROOT_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c 16)
echo "root:$ROOT_PASS" | chpasswd

# 3. Config SSH (INSTANT)
cat > /etc/ssh/sshd_config <<EOF
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Restart service ssh
systemctl restart ssh

# 4. Ambil Public IP (Gunakan wget agar pasti ada & cepat)
# Menggunakan icanhazip.com yang sangat ringan
VPS_IP=$(wget -qO- icanhazip.com)

# Fallback jika gagal ambil public IP, pakai hostname
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(hostname -I | awk '{print $1}')
fi

# 5. Output
echo "----------------------------------------"
echo "SETUP SELESAI!"
echo "----------------------------------------"
echo "IPv4     : $VPS_IP"
echo "User     : root"
echo "Password : $ROOT_PASS"
echo "Status   : SSH Root Active"
echo "----------------------------------------"
