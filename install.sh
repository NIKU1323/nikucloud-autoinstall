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

# ======================= SSL Let's Encrypt via ACME ========================
log_info "Memasang SSL Let's Encrypt via ACME..."

# Unduh dan pasang ACME
curl https://acme-install.netlify.app/acme.sh | sh

# Issue sertifikat dengan ACME (standalone mode, ECC 256-bit)
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256

# Simpan path sertifikat & key sementara
CERT_PATH="/root/.acme.sh/$DOMAIN_ecc/fullchain.cer"
KEY_PATH="/root/.acme.sh/$DOMAIN_ecc/$DOMAIN.key"

# Tampilkan ringkasan cert
log_success "✅ Sertifikat berhasil dibuat untuk $DOMAIN!"
echo -e "${YELLOW}Cuplikan isi cert:${NC}"
head -n 5 "$CERT_PATH"

# ========================== INSTALL XRAY CORE =============================
log_info "Menginstall Xray Core..."

mkdir -p /etc/xray /var/log/xray

UUID=$(cat /proc/sys/kernel/random/uuid)
echo "$UUID" > /etc/xray/uuid
echo "$DOMAIN" > /etc/xray/domain

# Salin SSL cert ke direktori Xray
log_info "Menyalin sertifikat ke /etc/xray..."
cp "$CERT_PATH" /etc/xray/cert.pem
cp "$KEY_PATH" /etc/xray/key.pem
log_success "✅ Sertifikat disalin ke /etc/xray/"

# Buat konfigurasi Xray default (VMESS, VLESS, TROJAN TLS WS di port 443)
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

# Buat systemd Xray
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
log_success "✅ Xray aktif dan berjalan di port 443 (TLS WS)"

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

log_info "Membuat struktur menu..."

mkdir -p /root/menu/{ssh,vmess,vless,trojan}

# ===== menu.sh =====
cat > /root/menu/menu.sh <<'EOF'
#!/bin/bash
NC='\e[0m'; GREEN='\e[32m'; YELLOW='\e[33m'; CYAN='\e[36m'; RED='\e[31m'
uptime_sys=$(uptime -p | cut -d " " -f2-)
os_name=$(hostnamectl | grep "Operating System" | cut -d ':' -f2 | xargs)
ram_total=$(free -m | awk '/Mem:/{print $2}')
ram_used=$(free -m | awk '/Mem:/{print $3}')
core=$(nproc)
domain=$(cat /etc/xray/domain)
ip_vps=$(curl -s ipv4.icanhazip.com)
city=$(curl -s ipinfo.io/city)
isp=$(curl -s ipinfo.io/org | cut -d " " -f2-10)
check_status(){ systemctl is-active $1 &>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"; }
status_ssh=$(check_status ssh); status_xray=$(check_status xray); status_nginx=$(check_status nginx)
ssh_count=$(ls /etc/ssh | wc -l 2>/dev/null); vmess_count=$(cat /etc/xray/vmess-users.txt 2>/dev/null | wc -l)
vless_count=$(cat /etc/xray/vless-users.txt 2>/dev/null | wc -l); trojan_count=$(cat /etc/xray/trojan-users.txt 2>/dev/null | wc -l)

clear
echo -e "${CYAN}────────────────────────────────────────────────────"
echo -e "         .::::. ${YELLOW}NIKU TUNNEL / MERCURYVPN${CYAN} .::::."
echo -e "────────────────────────────────────────────────────${NC}"
echo -e " ┌────────────────────────────────────────────┐"
echo -e " │ SYS OS : $os_name"
echo -e " │ RAM    : ${ram_total}MB / ${ram_used}MB"
echo -e " │ UPTIME : $uptime_sys"
echo -e " │ CORE   : $core"
echo -e " │ ISP    : $isp"
echo -e " │ CITY   : $city"
echo -e " │ IP     : $ip_vps"
echo -e " │ DOMAIN : $domain"
echo -e " └────────────────────────────────────────────┘"
echo -e " ┌────────────────────────────────────────────────┐"
echo -e " │ SSH-WS : $status_ssh │ XRAY : $status_xray │ NGINX : $status_nginx │  GOOD │"
echo -e " └────────────────────────────────────────────────┘"
echo -e "                 SSH OVPN : $ssh_count"
echo -e "                 VMESS    : $vmess_count"
echo -e "                 VLESS    : $vless_count"
echo -e "                 TROJAN   : $trojan_count"
echo -e " ┌────────────────────────────────────────────────┐"
echo -e " │ 1. SSH MANAGER         5. OTHER SETTINGS        │"
echo -e " │ 2. VMESS MANAGER       6. REBOOT VPS            │"
echo -e " │ 3. VLESS MANAGER       x. EXIT                  │"
echo -e " │ 4. TROJAN MANAGER                               │"
echo -e " └────────────────────────────────────────────────┘"
read -p "Select Menu: " opt
case $opt in
  1) bash /root/menu/menu-ssh.sh ;;
  2) bash /root/menu/menu-vmess.sh ;;
  3) bash /root/menu/menu-vless.sh ;;
  4) bash /root/menu/menu-trojan.sh ;;
  5) bash /root/menu/add-domain.sh ;;
  6) reboot ;;
  x) exit ;;
  *) bash /root/menu/menu.sh ;;
esac
EOF
chmod +x /root/menu/menu.sh

# ===== menu-ssh.sh =====
cat > /root/menu/menu-ssh.sh <<'EOF'
#!/bin/bash
echo -e "==== SSH MANAGER ===="
echo -e "[1] Create SSH"
echo -e "[2] Delete SSH"
echo -e "[3] Trial SSH"
echo -e "[x] Back to Menu"
read -p "Choose: " ssh_opt
case $ssh_opt in
  1) bash /root/menu/ssh/create.sh ;;
  2) echo "Delete SSH belum tersedia." ;;
  3) echo "Trial SSH belum tersedia." ;;
  x) bash /root/menu/menu.sh ;;
  *) bash /root/menu/menu-ssh.sh ;;
esac
EOF
chmod +x /root/menu/menu-ssh.sh

# ===== menu-vmess.sh =====
cat > /root/menu/menu-vmess.sh <<'EOF'
#!/bin/bash
echo -e "==== VMESS MANAGER ===="
echo -e "[1] Create VMESS"
echo -e "[2] Delete VMESS"
echo -e "[3] Trial VMESS"
echo -e "[x] Back to Menu"
read -p "Choose: " opt
case $opt in
  1) bash /root/menu/vmess/create.sh ;;
  2) echo "Delete VMESS belum tersedia." ;;
  3) echo "Trial VMESS belum tersedia." ;;
  x) bash /root/menu/menu.sh ;;
  *) bash /root/menu/menu-vmess.sh ;;
esac
EOF
chmod +x /root/menu/menu-vmess.sh

# ===== menu-vless.sh =====
cat > /root/menu/menu-vless.sh <<'EOF'
#!/bin/bash
echo -e "==== VLESS MANAGER ===="
echo -e "[1] Create VLESS"
echo -e "[2] Delete VLESS"
echo -e "[3] Trial VLESS"
echo -e "[x] Back to Menu"
read -p "Choose: " opt
case $opt in
  1) bash /root/menu/vless/create.sh ;;
  2) echo "Delete VLESS belum tersedia." ;;
  3) echo "Trial VLESS belum tersedia." ;;
  x) bash /root/menu/menu.sh ;;
  *) bash /root/menu/menu-vless.sh ;;
esac
EOF
chmod +x /root/menu/menu-vless.sh

# ===== menu-trojan.sh =====
cat > /root/menu/menu-trojan.sh <<'EOF'
#!/bin/bash
echo -e "==== TROJAN MANAGER ===="
echo -e "[1] Create TROJAN"
echo -e "[2] Delete TROJAN"
echo -e "[3] Trial TROJAN"
echo -e "[x] Back to Menu"
read -p "Choose: " opt
case $opt in
  1) bash /root/menu/trojan/create.sh ;;
  2) echo "Delete TROJAN belum tersedia." ;;
  3) echo "Trial TROJAN belum tersedia." ;;
  x) bash /root/menu/menu.sh ;;
  *) bash /root/menu/menu-trojan.sh ;;
esac
EOF
chmod +x /root/menu/menu-trojan.sh

# ===== create.sh dummy untuk semua protocol =====
for proto in ssh vmess vless trojan; do
  cat > /root/menu/$proto/create.sh <<-EOL
#!/bin/bash
echo "Create akun $proto berhasil. (dummy)"
EOL
  chmod +x /root/menu/$proto/create.sh
done

# add-domain.sh
cat > /root/menu/add-domain.sh <<'EOF'
#!/bin/bash
read -p "Masukkan domain baru: " new_domain
echo "$new_domain" > /etc/xray/domain
systemctl restart xray
echo "Domain diubah ke $new_domain dan Xray direstart."
EOF
chmod +x /root/menu/add-domain.sh

# auto run menu
echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc
log_success "Menu CLI terpasang otomatis!"



log_success "Instalasi semua selesai!"

read -p "Reboot VPS sekarang? (y/n): " reboot_confirm
[[ $reboot_confirm == "y" || $reboot_confirm == "Y" ]] && reboot
