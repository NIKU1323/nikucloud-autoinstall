#!/bin/bash
clear
echo "========= CREATE VMESS ACCOUNT ========="
read -p "Username        : " user
read -p "Masa aktif (hari): " masaaktif
read -p "Limit IP         : " iplimit
read -p "Limit Kuota (GB) : " kuota

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
domain=$(cat /etc/xray/domain)
porttls=443
path="/vmess"
userconf="/etc/xray/vmess-$user.json"

# Buat config
cat > $userconf <<EOF
{
  "inbounds": [],
  "outbounds": [],
  "clients": [
    {
      "id": "$uuid",
      "alterId": 0,
      "email": "$user"
    }
  ]
}
EOF

# Generate config xray
cat > /etc/xray/config.json <<EOF
{
  "log": { "loglevel": "info" },
  "inbounds": [{
    "port": $porttls,
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "$uuid",
          "alterId": 0,
          "email": "$user"
        }
      ]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "$path"
      },
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "/etc/xray/xray.crt",
            "keyFile": "/etc/xray/xray.key"
          }
        ]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# Restart service
systemctl restart xray

# Simpan data
mkdir -p /etc/xray/quota /etc/xray/iplimit
let "bytes = $kuota * 1024 * 1024 * 1024"
echo "$bytes" > /etc/xray/quota/$user
echo "$iplimit" > /etc/xray/iplimit/$user
echo "$user $exp" >> /etc/xray/akun-vmess.conf

# Config link
link="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"$porttls\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"$path\",\"type\":\"none\",\"host\":\"$domain\",\"tls\":\"tls\"}" | base64 -w 0)"

# Tampilkan hasil
clear
echo "===== VMESS ACCOUNT CREATED ====="
echo "Username : $user"
echo "Expired  : $exp"
echo "Domain   : $domain"
echo "Port TLS : $porttls"
echo "ID       : $uuid"
echo "Limit IP : $iplimit"
echo "Kuota GB : $kuota"
echo "Link     :"
echo "$link"
echo "================================="
echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
menu
