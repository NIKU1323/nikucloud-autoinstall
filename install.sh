#!/bin/bash
# AUTO INSTALLER - NIKU TUNNEL by MERCURYVPN
clear
echo "🔧 MEMULAI INSTALASI SEMUA FITUR NIKU TUNNEL..."

# Update dan install tools dasar
apt update -y && apt upgrade -y
apt install -y curl wget git nano iptables net-tools screen unzip                nginx dropbear openvpn easy-rsa squid stunnel4                python3 python3-pip socat cron haproxy resolvconf                jq build-essential libsqlite3-dev

# IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i '/net.ipv4.ip_forward/c\net.ipv4.ip_forward = 1' /etc/sysctl.conf
sysctl -p

# Setup rc.local
cat > /etc/rc.local <<-EOF
#!/bin/sh -e
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local

# Cron auto reboot
echo "0 5 * * * root /sbin/reboot" > /etc/cron.d/auto_reboot

# ✅ BadVPN
wget -q -O /usr/bin/badvpn-udpgw https://github.com/ambrop72/badvpn/releases/download/1.999.130/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100

# ✅ SSH WebSocket (Python)
wget -q -O /usr/local/bin/ws-ssh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/ws-ssh.py
chmod +x /usr/local/bin/ws-ssh
cat > /etc/systemd/system/ws-ssh.service <<-EOL
[Unit]
Description=SSH WebSocket by NIKU
After=network.target
[Service]
ExecStart=/usr/local/bin/ws-ssh
Restart=always
[Install]
WantedBy=multi-user.target
EOL
systemctl daemon-reexec
systemctl enable ws-ssh
systemctl start ws-ssh

# ✅ OpenSSH config
echo "Port 22" > /etc/ssh/sshd_config
echo "Port 443" >> /etc/ssh/sshd_config
systemctl restart ssh

# ✅ Dropbear config
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=109/g' /etc/default/dropbear
echo 'DROPBEAR_EXTRA_ARGS="-p 143"' >> /etc/default/dropbear
systemctl enable dropbear
systemctl restart dropbear

# ✅ Squid config
cat > /etc/squid/squid.conf <<-EOF
http_port 3128
http_port 8000
acl localnet src 0.0.0.0/0
http_access allow localnet
http_access deny all
EOF
systemctl restart squid

# ✅ HAProxy config
cat > /etc/haproxy/haproxy.cfg <<-EOF
global
    log /dev/log local0
    maxconn 2000
defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
frontend ssh
    bind *:2222
    default_backend ssh_pool
backend ssh_pool
    server ssh1 127.0.0.1:22
EOF
systemctl enable haproxy
systemctl restart haproxy

# ✅ SlowDNS
mkdir -p /etc/slowdns
wget -q -O /etc/slowdns/server.key https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/slowdns/server.key
wget -q -O /etc/slowdns/server.pub https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/slowdns/server.pub
wget -q -O /usr/bin/slowdns-server https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/slowdns/sldns-server
chmod +x /usr/bin/slowdns-server

# ✅ UDP Custom
wget -q -O /usr/bin/udp-custom https://github.com/ambrop72/udp-custom/releases/download/latest/udp-custom-linux-amd64
chmod +x /usr/bin/udp-custom
screen -dmS udp /usr/bin/udp-custom server --listen 127.0.0.1:7300 --max-clients 200

# ✅ NGINX Webserver
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/conf.d/niku.conf <<-EOF
server {
    listen 81 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
}
EOF
mkdir -p /var/www/html
echo "<h1>Welcome to NIKU TUNNEL</h1>" > /var/www/html/index.html
systemctl enable nginx
systemctl restart nginx

# ✅ Input Domain
read -p "Masukkan domain kamu (sudah dipointing ke VPS): " domain
mkdir -p /etc/xray
echo "$domain" > /etc/xray/domain

# ✅ Install SSL Let's Encrypt
apt install -y socat
curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --register-account -m niku@niku.cloud
~/.acme.sh/acme.sh --issue --standalone -d $domain --force
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key

# ✅ XRAY
mkdir -p /etc/xray/conf
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o Xray-linux-64.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray

# Konfigurasi VMESS TLS
cat > /etc/xray/conf/10-vmess.json <<-EOF
{
  "inbounds": [{
    "port": 443,
    "protocol": "vmess",
    "settings": {
      "clients": []
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "/etc/xray/xray.crt",
          "keyFile": "/etc/xray/xray.key"
        }]
      },
      "wsSettings": {
        "path": "/vmess"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

# Service Xray
cat > /etc/systemd/system/xray.service <<-EOF
[Unit]
Description=Xray Service
After=network.target
[Service]
ExecStart=/usr/local/bin/xray -config /etc/xray/conf/10-vmess.json
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

# ✅ UNDUH SEMUA FILE MENU
echo "📥 Mengunduh file menu..."

MENU_URL_BASE="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"

declare -A MENUS=(
    [menu]=menu.sh
    [menu-ssh]=menu-ssh.sh
    [menu-vmess]=menu-vmess.sh
    [menu-vless]=menu-vless.sh
    [menu-trojan]=menu-trojan.sh
    [add-domain]=add-domain.sh
)

for key in "${!MENUS[@]}"; do
    file="${MENUS[$key]}"
    wget -q -O "/usr/bin/$key" "$MENU_URL_BASE/$file"
    chmod +x "/usr/bin/$key"
done

echo ""
echo "✅ INSTALASI LENGKAP SEMUA FITUR NIKU TUNNEL!"
echo "🔁 Menjalankan menu utama..."
sleep 1
menu
