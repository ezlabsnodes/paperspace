#!/bin/bash
# fast-secure-setup.sh - Cepat & Tetap Aman

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

echo "=== MEMULAI SETUP (FAST & SECURE) ==="

# 1. Generate password di awal
ROOT_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c 16)
echo "root:$ROOT_PASS" | chpasswd

# 2. Install Fail2Ban & Config SSH secara paralel
(
    apt update -y >/dev/null 2>&1
    apt install -y fail2ban >/dev/null 2>&1
    
    # Konfigurasi Fail2Ban: Blokir 1 jam jika salah 3 kali
    cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port    = 22
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF
    systemctl restart fail2ban
    systemctl enable fail2ban >/dev/null 2>&1
) &

# 3. Konfigurasi SSH (Langsung Timpa)
cat > /etc/ssh/sshd_config <<EOF
Port 22
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

systemctl restart ssh

# 4. Ambil IP
VPS_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')

echo "----------------------------------------"
echo "SETUP SELESAI!"
echo "----------------------------------------"
echo "IPv4     : $VPS_IP"
echo "User     : root"
echo "Password : $ROOT_PASS"
echo "Status   : SSH Active, Fail2Ban Configured"
echo "----------------------------------------"
echo "Catatan: Fail2Ban sedang aktif di background."
