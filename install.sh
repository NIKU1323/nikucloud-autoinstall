#!/bin/bash
# AUTO INSTALL VPN FULL PACKAGE + TLS + WS + gRPC
# Brand: NIKU TUNNEL / MERCURYVPN

# Color log
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

apt update -y && apt install -y jq curl socat openssl wget unzip screen nginx dropbear squid haproxy python3 python3-pip

# Validasi IP VPS
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

# Install SSL Let's Encrypt
log_info "Menghentikan nginx sementara..."
systemctl stop nginx
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256 --server letsencrypt
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --fullchain-file /etc/xray/cert.pem \
  --key-file /etc/xray/key.pem \
  --ecc || { log_error "Gagal pasang SSL"; exit 1; }
cat /etc/xray/cert.pem /etc/xray/key.pem > /etc/xray/haproxy.pem
chmod 600 /etc/xray/haproxy.pem
systemctl start nginx

# Install Xray
mkdir -p /var/log/xray /tmp/xray && cd /tmp/xray
XRAY_URL=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
wget "$XRAY_URL" -O xray.zip && unzip xray.zip
install -m 755 xray /usr/bin/xray
install -m 755 geo* /usr/share/xray/
echo $(cat /proc/sys/kernel/random/uuid) > /etc/xray/uuid

# Config Xray (VMESS, VLESS, TROJAN TLS + nonTLS + WS + gRPC)
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    { "port": 443, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "security": "tls", "grpcSettings": { "serviceName": "vmess-grpc" } } },
    { "port": 80, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vmess" } } },

    { "port": 443, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "security": "tls", "grpcSettings": { "serviceName": "vless-grpc" } } },
    { "port": 8080, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/vless" } } },

    { "port": 443, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "security": "tls", "grpcSettings": { "serviceName": "trojan-grpc" } } },
    { "port": 2096, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "security": "none", "wsSettings": { "path": "/trojan" } } }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# Service Xray
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
systemctl enable xray && systemctl restart xray

# HAProxy multiport: TLS 443 untuk SSH dan Xray
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    daemon
    maxconn 2048

defaults
    mode tcp
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend ssl_in
    bind *:443 ssl crt /etc/xray/haproxy.pem
    mode tcp
    option tcplog
    use_backend xray_tls if { req.ssl_sni -m end .$DOMAIN }
    default_backend ssh_tls

backend xray_tls
    mode tcp
    server xray 127.0.0.1:443

backend ssh_tls
    mode tcp
    server ssh 127.0.0.1:22
EOF
systemctl enable haproxy && systemctl restart haproxy

# NGINX WS forward
cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 80;
    server_name _;

    location /vmess {
        proxy_pass http://127.0.0.1:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location /vless {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location /trojan {
        proxy_pass http://127.0.0.1:2096;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
systemctl restart nginx

log_info "Pasang menu CLI..."
mkdir -p /root/menu && cd /root/menu

wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-tools.sh

# ✅ Tambahkan ini untuk download create.sh
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
