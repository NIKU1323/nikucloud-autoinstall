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
ALLOWED_URL="https://niku-vpn.site/allowed.json" # GANTI URL SESUAI SERVERMU

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
# Buat direktori rc.local
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

# SSL Let's Encrypt via ACME
log_info "Memasang SSL via ACME..."
curl https://acme-install.netlify.app/acme.sh | sh
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
  --key-file /etc/xray/key.pem \
  --fullchain-file /etc/xray/cert.pem

# Install Xray
log_info "Install Xray Core..."
mkdir -p /etc/xray /var/log/xray
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/xray/uuid

cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "default-vmess"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "default-vless"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID",
            "email": "default-trojan"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/trojan"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# Aktifkan Xray Service
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
# Install SSH & Dropbear
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

# Squid & HAProxy
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
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
frontend http-in
    bind *:80
    default_backend servers
backend servers
    server server1 127.0.0.1:3128 maxconn 32
EOF

systemctl enable haproxy
systemctl restart haproxy

# Nginx Web Server
log_info "Setting Nginx..."
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 81 default_server;
    root /var/www/html;
    index index.html;
}
EOF
systemctl restart nginx

# SlowDNS placeholder
mkdir -p /etc/slowdns
# Install menu CLI
log_info "Pasang menu CLI..."
mkdir -p /root/menu
cd /root/menu
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menussh.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menuvmess.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menuvless.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menutrojan.sh
wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/add-domain.sh
chmod +x *.sh

# Auto menu saat login
echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc

# BOT Telegram IP Registrasi
log_info "Memasang BOT Telegram IP Registrasi..."
mkdir -p /etc/niku-bot
cat > /etc/niku-bot/bot.py <<EOF
print("Bot placeholder. Ganti dengan script asli.")
EOF

cat > /etc/niku-bot/config.json <<EOF
{
  "bot_token": "ISI_TOKEN_BOT",
  "admin_id": "ISI_ADMIN_ID"
}
EOF

cat > /etc/niku-bot/allowed.json <<EOF
[]
EOF

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

log_success "Instalasi semua selesai!"

read -p "Reboot VPS sekarang? (y/n): " reboot_confirm
[[ $reboot_confirm == "y" || $reboot_confirm == "Y" ]] && reboot
