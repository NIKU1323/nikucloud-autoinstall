#!/bin/bash
# AUTO INSTALL VPN FULL PACKAGE + GRPC + XRAY + SSH + SSL
# Brand: NIKU TUNNEL / MERCURYVPN

# Warna log
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

clear
log_info "Menyiapkan instalasi NIKU TUNNEL..."

# Cek root
if [[ $EUID -ne 0 ]]; then
   log_error "Script ini harus dijalankan sebagai root"
   exit 1
fi

apt update -y
apt install -y jq curl wget unzip socat openssl git python3 python3-pip lsb-release cron bash-completion screen netfilter-persistent nginx dropbear squid haproxy

# Validasi IP VPS dari allowed.json
IPVPS=$(curl -s ipv4.icanhazip.com)
ALLOWED_URL="http://172.236.138.192/data/allowed.json"

log_info "Memvalidasi IP VPS ($IPVPS)..."
EXPIRED=$(curl -s --max-time 10 "$ALLOWED_URL" | jq -r '.[] | select(.ip=="'$IPVPS'") | .exp')
if [[ -n "$EXPIRED" ]]; then
    log_success "IP VPS terdaftar. Lanjutkan instalasi..."
else
    log_error "IP VPS ($IPVPS) belum terdaftar. Hubungi admin Telegram."
    exit 1
fi

# Input domain
read -p "Masukkan domain pointing ke VPS ini: " DOMAIN
mkdir -p /etc/xray
echo "$DOMAIN" > /etc/xray/domain

# SSL Let's Encrypt pakai ACME.SH
log_info "Menghentikan nginx sementara..."
systemctl stop nginx

curl https://get.acme.sh | sh
source ~/.bashrc

/root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 --server letsencrypt

/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --fullchain-file /etc/xray/cert.pem \
  --key-file /etc/xray/key.pem \
  --ecc

if [[ -f /etc/xray/cert.pem && -f /etc/xray/key.pem ]]; then
  log_success "Sertifikat SSL berhasil dibuat!"
else
  log_error "Gagal membuat SSL. Pastikan domain mengarah ke IP VPS!"
  exit 1
fi

cat /etc/xray/cert.pem /etc/xray/key.pem > /etc/xray/haproxy.pem
chmod 600 /etc/xray/haproxy.pem
systemctl start nginx

# Install Xray
log_info "Install Xray Core..."
mkdir -p /var/log/xray /tmp/xray
cd /tmp/xray
LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
wget -q "$LATEST" -O xray.zip
unzip -o xray.zip
install -m 755 xray /usr/bin/xray
install -m 755 geo* /usr/share/xray/
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/xray/uuid

# Config Xray (WS & gRPC)
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {"port": 8880, "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmess"}}},
    {"port": 8881, "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vless"}}},
    {"port": 8882, "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojan"}}},

    {"port": 2096, "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vmess-grpc"}, "security": "tls"}},
    {"port": 2097, "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "vless-grpc"}, "security": "tls"}},
    {"port": 2098, "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "grpc", "grpcSettings": {"serviceName": "trojan-grpc"}, "security": "tls"}}
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
ExecStart=/usr/bin/xray run -c /etc/xray/config.json
Restart=on-failure
User=root
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# HAProxy SSL untuk SSH
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    daemon
    maxconn 256
defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
frontend ssl_ssh
    bind *:443 ssl crt /etc/xray/haproxy.pem
    mode tcp
    default_backend ssh_backend
backend ssh_backend
    mode tcp
    server ssh 127.0.0.1:22
EOF
systemctl enable haproxy && systemctl restart haproxy

# NGINX WS
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 80;
    server_name _;
    location /vmess { proxy_pass http://127.0.0.1:8880; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /vless { proxy_pass http://127.0.0.1:8881; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
    location /trojan { proxy_pass http://127.0.0.1:8882; proxy_http_version 1.1; proxy_set_header Upgrade \$http_upgrade; proxy_set_header Connection "upgrade"; }
}
EOF
nginx -t && systemctl restart nginx

# Menu CLI
log_info "Pasang menu CLI..."
mkdir -p /root/menu && cd /root/menu
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-tools.sh
chmod +x *.sh

mkdir -p /root/menu/ssh
wget -q -O /root/menu/ssh/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/create.sh
wget -q -O /root/menu/ssh/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/autokill.sh
wget -q -O /root/menu/ssh/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/cek.sh
wget -q -O /root/menu/ssh/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/lock.sh
wget -q -O /root/menu/ssh/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/list.sh
wget -q -O /root/menu/ssh/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/delete-exp.sh
wget -q -O /root/menu/ssh/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/delete.sh
wget -q -O /root/menu/ssh/unlock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/unlock.sh
wget -q -O /root/menu/ssh/trial.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/trial.sh
wget -q -O /root/menu/ssh/multilogin.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/multilogin.sh
wget -q -O /root/menu/ssh/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/renew.sh

mkdir -p /root/menu/vmess
wget -q -O /root/menu/vmess/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/create.sh
wget -q -O /root/menu/vmess/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/renew.sh
wget -q -O /root/menu/vmess/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/cek.sh
wget -q -O /root/menu/vmess/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/trial.sh
wget -q -O /root/menu/vmess/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/list.sh
wget -q -O /root/menu/vmess/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/delete-exp.sh
wget -q -O /root/menu/vmess/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/delete.sh

mkdir -p /root/menu/vless
wget -q -O /root/menu/vless/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/create.sh
wget -q -O /root/menu/vless/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/renew.sh
wget -q -O /root/menu/vless/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/cek.sh
wget -q -O /root/menu/vless/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/trial.sh
wget -q -O /root/menu/vless/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/list.sh
wget -q -O /root/menu/vless/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/delete-exp.sh
wget -q -O /root/menu/vless/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/delete.sh

mkdir -p /root/menu/trojan
wget -q -O /root/menu/trojan/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/create.sh
wget -q -O /root/menu/trojan/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/renew.sh
wget -q -O /root/menu/trojan/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/cek.sh
wget -q -O /root/menu/trojan/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/trial.sh
wget -q -O /root/menu/trojan/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/list.sh
wget -q -O /root/menu/trojan/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/delete-exp.sh
wget -q -O /root/menu/trojan/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/delete.sh

chmod +x /root/menu/*.sh
chmod +x /root/menu/menu-tools/*.sh
chmod +x /root/menu/ssh/*.sh
chmod +x /root/menu/vless/*.sh
chmod +x /root/menu/trojan/*.sh
chmod +x /root/menu/vmess/*.sh
[[ $(grep -c menu.sh /root/.bashrc) == 0 ]] && echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc

# Biar bisa akses cukup ketik "menu"
ln -sf /root/menu/menu.sh /usr/local/bin/menu
chmod +x /usr/local/bin/menu

log_success "✅ INSTALLASI BERHASIL! Jalankan ulang VPS dan tes koneksi di aplikasi."
read -p "Reboot sekarang? (y/n): " jawab
[[ "$jawab" == "y" || "$jawab" == "Y" ]] && reboot
