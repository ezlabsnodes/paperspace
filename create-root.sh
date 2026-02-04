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
# Timpa config sshd agar root bisa login password
cat > /etc/ssh/sshd_config <<EOF
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Restart service ssh (sangat cepat)
systemctl restart ssh

# 4. Ambil IP (Lokal, tidak butuh internet)
VPS_IP=$(hostname -I | awk '{print $1}')

# 5. Output (Format Sama)
echo "----------------------------------------"
echo "SETUP SELESAI!"
echo "----------------------------------------"
echo "IPv4     : $VPS_IP"
echo "User     : root"
echo "Password : $ROOT_PASS"
echo "Status   : SSH Root Active"
echo "----------------------------------------"
echo "Catatan: Tidak ada background process."
