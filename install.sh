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
apt install -y jq curl

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

# Update system & install tools dasar
log_info "Update & install tools..."
apt update -y && apt upgrade -y
apt install -y socat curl wget unzip screen netfilter-persistent cron bash-completion lsb-release python3 python3-pip nginx jq git dropbear squid haproxy

# Setup rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
exit 0
END
chmod +x /etc/rc.local

# Install BadVPN
log_info "Install BadVPN..."
wget -q -O /usr/bin/badvpn-udpgw "https://github.com/ambrop72/badvpn/releases/download/v1.999.130/badvpn-udpgw"
chmod +x /usr/bin/badvpn-udpgw
cat > /etc/systemd/system/badvpn.service <<-EOF
[Unit]
Description=BadVPN UDPGW
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable badvpn
systemctl start badvpn

# Install UDP Custom
log_info "Install UDP Custom..."
wget -q -O /usr/bin/udp-custom "https://github.com/aztecmx/udp-custom/releases/latest/download/udp-custom-linux-amd64"
chmod +x /usr/bin/udp-custom
cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Service
After=network.target
[Service]
ExecStart=/usr/bin/udp-custom server --listen 7300 --to 127.0.0.1:22
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable udp-custom
systemctl start udp-custom

log_info "Menghentikan nginx sementara untuk generate SSL..."
systemctl stop nginx

# Install ACME & SSL
log_info "Pasang SSL Let's Encrypt..."
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
 --fullchain-file /etc/xray/cert.pem \
 --key-file /etc/xray/key.pem \
 --ecc

log_info "Menyalakan kembali nginx..."
systemctl start nginx

cat /etc/xray/cert.pem /etc/xray/key.pem > /etc/xray/haproxy.pem
chmod 600 /etc/xray/haproxy.pem

# Install Xray Core
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
log_success "Xray terpasang. UUID: $UUID"

# Config lengkap Xray (VMESS, VLESS, TROJAN) WS + gRPC
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

# Xray systemd
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

# Dropbear
systemctl enable dropbear && systemctl restart dropbear

# Squid
cat > /etc/squid/squid.conf <<EOF
http_port 3128
http_port 8080
acl all src all
http_access allow all
EOF
systemctl enable squid && systemctl restart squid

# HAProxy
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
systemctl daemon-reload && systemctl enable haproxy && systemctl restart haproxy

# NGINX WS support
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
nginx -t && systemctl restart nginx && log_success "NGINX siap!"

# Menu CLI
log_info "Pasang menu CLI..."
mkdir -p /root/menu && cd /root/menu
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/add-domain.sh
chmod +x *.sh
[[ $(grep -c menu.sh /root/.bashrc) == 0 ]] && echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc

log_success "✅ Instalasi selesai!"
read -p "Reboot VPS sekarang? (y/n): " jawab
[[ "$jawab" == "y" || "$jawab" == "Y" ]] && reboot
