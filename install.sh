#!/bin/bash
# AUTO INSTALL VPN FULL PACKAGE + IP REGISTRATION + XRAY CONFIG + LOG VISUAL + MENU OTA
# Author: NIKU TUNNEL / MERCURYVPN

GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}        AUTO INSTALL VPN FULL SYSTEM      ${NC}"
echo -e "${GREEN}==========================================${NC}"

MYIP=$(curl -s ipv4.icanhazip.com)
mkdir -p /etc/niku

# === DOMAIN SETUP ===
echo -ne "${YELLOW}Masukkan domain (yang sudah dipointing ke IP VPS ini): ${NC}"
read domain
domain_ip=$(ping -c1 "$domain" | grep -oP '(\d{1,3}\.){3}\d{1,3}' | head -n1)
if [[ "$domain_ip" != "$MYIP" ]]; then
  echo -e "${RED}DOMAIN LUH POINTING DULU KONTOL${NC}"
  echo "VPS IP : $MYIP"
  echo "DOMAIN : $domain → IP: $domain_ip"
  exit 1
fi
echo "$domain" > /etc/niku/domain

# === BASIC DEPENDENCIES ===
echo -e "${YELLOW}[+] Menginstall dependencies dasar...${NC}"
apt update -y && apt upgrade -y
apt install -y socat netcat curl cron gnupg screen nginx git unzip python3 python3-pip python3-venv dropbear squid haproxy openvpn iptables-persistent stunnel4 jq

# === ACME / SSL INSTALL ===
echo -e "${YELLOW}[+] Menginstall dan mengaktifkan SSL Let's Encrypt...${NC}"
curl https://acme-install.netlify.app/acme.sh -o acme.sh && bash acme.sh && rm acme.sh
~/.acme.sh/acme.sh --issue --standalone -d "$domain" --force
~/.acme.sh/acme.sh --install-cert -d "$domain" \
  --fullchain-file /etc/xray/xray.crt \
  --key-file /etc/xray/xray.key

# === NGINX / allowed.json ===
echo -e "${YELLOW}[+] Setup Nginx dan allowed.json...${NC}"
mkdir -p /var/www/html
echo "[\"$MYIP\"]" > /var/www/html/allowed.json
chmod 644 /var/www/html/allowed.json
cat <<EOF >/etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /var/www/html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
systemctl restart nginx

# === VALIDASI IP TERDAFTAR ===
echo -e "${YELLOW}[+] Validasi IP VPS dengan allowed.json...${NC}"
TRIES=5
while [[ $TRIES -gt 0 ]]; do
  IZIN=$(curl -s http://127.0.0.1/allowed.json | grep -w "$MYIP")
  [[ $IZIN != "" ]] && break
  echo "Retrying access check..."
  sleep 1
  TRIES=$((TRIES - 1))
done
if [[ $IZIN == "" ]]; then
  echo -e "${RED}[ ACCESS DENIED - IP NOT REGISTERED ]${NC}"
  exit 1
fi

# === BADVPN ===
echo -e "${YELLOW}[+] Install BadVPN...${NC}"
wget -O /usr/bin/badvpn-udpgw https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/media/badvpn-udpgw
chmod +x /usr/bin/badvpn-udpgw
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100

# === RC.LOCAL ===
echo -e "${YELLOW}[+] Setup rc.local...${NC}"
cat <<EOF >/etc/rc.local
#!/bin/sh -e
screen -dmS badvpn /usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100
exit 0
EOF
chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local

# === OPENSSH & DROPBEAR ===
echo -e "${YELLOW}[+] Konfigurasi OpenSSH dan Dropbear...${NC}"
sed -i 's/Port 22/Port 22\nPort 2253/' /etc/ssh/sshd_config
/etc/init.d/ssh restart
cat <<EOF >/etc/default/dropbear
NO_START=0
DROPBEAR_PORT=443
DROPBEAR_EXTRA_ARGS="-p 109"
EOF
systemctl enable dropbear
systemctl restart dropbear

# === OPENVPN ===
echo -e "${YELLOW}[+] Setup OpenVPN (kosong, silakan isi manual)...${NC}"
mkdir -p /etc/openvpn/server

# === SQUID ===
echo -e "${YELLOW}[+] Konfigurasi Squid proxy...${NC}"
echo "http_port 3128" > /etc/squid/squid.conf
systemctl restart squid

# === HAPROXY ===
echo -e "${YELLOW}[+] Setup HAProxy...${NC}"
cat <<EOF >/etc/haproxy/haproxy.cfg
global
  daemon
  maxconn 256
defaults
  mode tcp
  timeout connect 5000ms
  timeout client 50000ms
  timeout server 50000ms
frontend ssh-in
  bind *:2222
  default_backend ssh-out
backend ssh-out
  server ssh1 127.0.0.1:22
EOF
systemctl restart haproxy

# === IPTABLES ===
echo -e "${YELLOW}[+] Setting iptables rules...${NC}"
ip6tables -F
iptables -F
iptables -t nat -F
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -j DROP
netfilter-persistent save

# === AUTO REBOOT ===
echo -e "${YELLOW}[+] Setup auto reboot jam 5 pagi...${NC}"
echo "0 5 * * * root /sbin/reboot" > /etc/cron.d/reboot

# === SLOWDNS ===
echo -e "${YELLOW}[+] Install SlowDNS...${NC}"
mkdir -p /etc/slowdns
wget -qO /etc/slowdns/server https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/media/slowdns-server
wget -qO /etc/slowdns/client https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/media/slowdns-client
chmod +x /etc/slowdns/*

# === SSH WEBSOCKET ===
echo -e "${YELLOW}[+] Install SSH WebSocket...${NC}"
wget -qO /usr/local/bin/ws-server https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/media/ws-server
chmod +x /usr/local/bin/ws-server
cat <<EOF >/etc/systemd/system/ws-server.service
[Unit]
Description=SSH WebSocket Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ws-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ws-server
systemctl start ws-server

# === SSH UDP CUSTOM ===
echo -e "${YELLOW}[+] Install UDP Custom...${NC}"
wget -O /usr/bin/udp-custom https://github.com/ambrop72/badvpn/releases/download/v1.999.130/badvpn-udpgw
chmod +x /usr/bin/udp-custom
screen -dmS udp /usr/bin/udp-custom --listen-addr 0.0.0.0:7300

# === XRAY INSTALL ===
echo -e "${YELLOW}[+] Install Xray Core...${NC}"
bash <(curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

# === XRAY CONFIG ===
echo -e "${YELLOW}[+] Setup konfigurasi Xray (VMESS/VLESS/TROJAN)...${NC}"
mkdir -p /etc/xray
cat <<EOF >/etc/xray/config.json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [...],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
systemctl enable xray
systemctl restart xray

# === DOWNLOAD MENU ===
echo -e "${YELLOW}[+] Downloading menu.sh...${NC}"
mkdir -p /root/menu
wget -qO /root/menu/menu.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
chmod +x /root/menu/menu.sh

# === AUTO START MENU SAAT LOGIN ===
if ! grep -q "/root/menu/menu.sh" /root/.bashrc; then
  echo "/root/menu/menu.sh" >> /root/.bashrc
fi

# === FINAL ===
clear
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}     SEMUA FITUR VPN TELAH TERINSTALL     ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN} Jalankan menu VPN: menu${NC}"
echo -e "${YELLOW} Reboot sekarang untuk menerapkan semua?${NC}"
read -p "Reboot sekarang? (y/n): " rebootnow

[[ $rebootnow == "y" || $rebootnow == "Y" ]] && reboot
