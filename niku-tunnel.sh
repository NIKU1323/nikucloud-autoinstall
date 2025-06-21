#!/bin/bash

# NIKU TUNNEL – MERCURYVPN ALL-IN-ONE INSTALLER
# SSH + VMESS + SSL + MENU + ALIAS + NO ROOT PASSWORD CHANGE

clear
blue="\033[1;34m"
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
cyan="\033[1;36m"
plain="\033[0m"

# ====== KONFIG BOT (ISI MANUAL) ======
BOT_TOKEN="ISI_BOT_TOKEN_LO"
ADMIN_ID="ISI_ADMIN_ID_LO"

# ====== Input Domain ======
echo -ne "\nMasukkan domain (sudah di-pointing ke VPS): "; read DOMAIN
mkdir -p /etc/niku
echo "$DOMAIN" > /etc/niku/domain

# ====== Install Dependensi Dasar ======
echo -e "${cyan}[•] Install package dasar...${plain}"
apt update -y && apt upgrade -y && apt install socat curl cron unzip wget git python3 python3-pip net-tools dropbear stunnel4 -y >/dev/null 2>&1

# ====== Install SSL Let's Encrypt (acme.sh) ======
echo -e "${cyan}[•] Pasang SSL Let's Encrypt...${plain}"
curl https://get.acme.sh | sh >/dev/null 2>&1
~/.acme.sh/acme.sh --register-account -m admin@$DOMAIN >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --force --keylength ec-256
mkdir -p /etc/xray
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
--key-file /etc/xray/key.pem \
--fullchain-file /etc/xray/cert.pem >/dev/null 2>&1

# ====== Install Xray Core ======
echo -e "${cyan}[•] Install Xray Core...${plain}"
cd /etc/xray
wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -o Xray-linux-64.zip >/dev/null 2>&1
chmod +x xray && mv xray /usr/local/bin/

# ====== Konfigurasi Xray ======
cat > /etc/xray/config.json << EOF
{
  "log": { "loglevel": "none" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{"certificateFile": "/etc/xray/cert.pem", "keyFile": "/etc/xray/key.pem"}]
        },
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": { "path": "/vmess" }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ====== Enable Service Xray ======
cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ====== Menu Manual ======
cat > /root/menu.sh << 'MENU'
#!/bin/bash
clear
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;36m     NIKU TUNNEL - MERCURYVPN MENU\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "1. Buat akun SSH"
echo -e "2. Buat akun VMESS"
echo -e "3. Restart Xray"
echo -e "4. Tampilkan log Xray"
echo -e "5. Keluar"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "Pilih opsi [1-5]: " pilih
case $pilih in
  1)
    read -p "Username SSH: " user
    read -p "Masa aktif (hari): " days
    pass="123"
    exp=$(date -d "+$days days" +%Y-%m-%d)
    useradd -e $exp -s /bin/false -M $user
    echo "$user:$pass" | chpasswd
    echo -e "\n✅ SSH berhasil dibuat untuk $user, password: $pass, exp: $exp\n"
    bash /root/menu.sh
    ;;
  2)
    uuid=$(cat /proc/sys/kernel/random/uuid)
    read -p "Username VMESS: " user
    read -p "Masa aktif (hari): " days
    exp=$(date -d "+$days days" +%Y-%m-%d)
    domain=$(cat /etc/niku/domain)
    sed -i "/clients": \[/a\        {\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}," /etc/xray/config.json
    systemctl restart xray
    vmess_link=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\"}" | base64 -w 0)
    echo -e "\n✅ VMESS berhasil dibuat\nLink: vmess://$vmess_link\n"
    bash /root/menu.sh
    ;;
  3)
    systemctl restart xray && echo "✅ Xray berhasil direstart" && bash /root/menu.sh
    ;;
  4)
    journalctl -u xray --no-pager | tail -n 20 && bash /root/menu.sh
    ;;
  5)
    exit
    ;;
  *)
    echo "❌ Pilihan tidak valid."
    bash /root/menu.sh
    ;;
esac
MENU
chmod +x /root/menu.sh

# ====== Tambahkan alias menu ======
sed -i '/alias menu=/d' ~/.bashrc
echo "alias menu='bash /root/menu.sh'" >> ~/.bashrc
source ~/.bashrc

# ====== Pesan Sukses ======
clear
echo -e "\n\033[1;32m✅ Instalasi selesai!\033[0m"
echo -e "Ketik \033[1;33mmenu\033[0m untuk membuka panel."
