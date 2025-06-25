#!/bin/bash
# AUTO INSTALL VPN FULL PACKAGE + IP REGISTRATION + XRAY CONFIG + MENU + BOT
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

# Validasi IP VPS dari allowed.json
IPVPS=$(curl -s ipv4.icanhazip.com)
ALLOWED_URL="http://52.77.219.228/allowed.json" # GANTI URL SESUAI SERVERMU

log_info "Memvalidasi IP VPS ($IPVPS)..."
if curl -s --max-time 10 "$ALLOWED_URL" | grep -qw "$IPVPS"; then
    log_success "IP VPS terdaftar. Lanjutkan instalasi..."
else
    log_error "IP VPS ($IPVPS) belum terdaftar. Hubungi admin Telegram."
    exit 1
fi

# Input domain
read -p "Masukkan domain pointing ke VPS ini: " DOMAIN
echo "$DOMAIN" > /etc/xray/domain

# Update system & install basic tools
log_info "Update & install tools dasar..."
apt update -y && apt upgrade -y
apt install -y socat curl wget screen unzip netfilter-persistent cron bash-completion lsb-release python3 python3-pip nginx jq git

# Buat rc.local
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
systemctl enable badvpn
systemctl start badvpn

# Install SSL Let's Encrypt via ACME
log_info "Memasang SSL Let's Encrypt via ACME..."
curl https://acme-install.netlify.app/acme.sh | sh
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256

CERT_PATH="/root/.acme.sh/$DOMAIN_ecc/fullchain.cer"
KEY_PATH="/root/.acme.sh/$DOMAIN_ecc/$DOMAIN.key"

cp "$CERT_PATH" /etc/xray/cert.pem
cp "$KEY_PATH" /etc/xray/key.pem

# Install Xray
log_info "Mengunduh dan menginstall Xray Core..."
mkdir -p /etc/xray /var/log/xray
mkdir -p /tmp/xray && cd /tmp/xray

LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
wget -q "$LATEST" -O xray.zip
unzip -o xray.zip
install -m 755 xray /usr/bin/xray
install -m 755 geo* /usr/share/xray/

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/xray/uuid
log_success "✅ Xray Core berhasil dipasang!"

# Dummy config minimal
cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=/usr/bin/xray run -c /etc/xray/config.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

# Install Dropbear & UDP Custom
log_info "Install Dropbear & UDP Custom..."
apt install -y dropbear
systemctl enable dropbear
systemctl restart dropbear

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
systemctl enable udp-custom
systemctl start udp-custom

# Install Squid & HAProxy
log_info "Install Squid & HAProxy..."
apt install -y squid haproxy
cat > /etc/squid/squid.conf <<EOF
http_port 3128
http_port 8080
acl all src all
http_access allow all
EOF
systemctl enable squid
systemctl restart squid

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
    bind *:443 ssl crt /etc/xray/cert.pem key /etc/xray/key.pem
    mode tcp
    default_backend ssh_backend

backend ssh_backend
    mode tcp
    server ssh 127.0.0.1:22
EOF
systemctl enable haproxy
systemctl restart haproxy

# Setup NGINX lengkap
log_info "Mengatur konfigurasi NGINX untuk WS + TLS + Payload Support..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default
rm -f /etc/nginx/conf.d/vpn.conf

cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 81 default_server;
    root /var/www/html;
    index index.html;
}

server {
    listen 80;
    server_name _;

    location /ssh {
        proxy_pass http://127.0.0.1:22;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vmess {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vless {
        proxy_pass http://127.0.0.1:8881;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /trojan {
        proxy_pass http://127.0.0.1:8882;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/xray/cert.pem;
    ssl_certificate_key /etc/xray/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location /ssh {
        proxy_pass http://127.0.0.1:22;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vmess {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /vless {
        proxy_pass http://127.0.0.1:8881;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

    location /trojan {
        proxy_pass http://127.0.0.1:8882;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

nginx -t && systemctl restart nginx && log_success "NGINX berhasil dikonfigurasi untuk WS dan TLS"

# Install menu CLI
log_info "Pasang menu CLI..."
mkdir -p /root/menu
cd /root/menu
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
chmod +x /root/menu/menu.sh

# Auto run menu saat login
if ! grep -q "menu.sh" /root/.bashrc; then
  echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc
fi

# Setup Telegram Bot (placeholder)
log_info "Setup Telegram Bot registrasi IP..."
mkdir -p /etc/niku-bot
cat > /etc/systemd/system/niku-bot.service <<EOF
[Unit]
Description=NIKU Tunnel Telegram Bot
After=network.target
[Service]
WorkingDirectory=/etc/niku-bot
ExecStart=/usr/bin/python3 /etc/niku-bot/bot.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reexec
systemctl enable niku-bot
systemctl start niku-bot

log_success "Instalasi selesai!"
read -p "Reboot VPS sekarang? (y/n): " reboot_confirm
[[ $reboot_confirm == "y" || $reboot_confirm == "Y" ]] && reboot
