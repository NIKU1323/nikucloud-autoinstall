#!/bin/bash
clear
echo "========= CREATE VLESS ACCOUNT ========="
read -p "Username        : " user
read -p "Masa aktif (hari): " masaaktif
read -p "Limit IP         : " iplimit
read -p "Limit Kuota (GB) : " kuota

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
domain=$(cat /etc/xray/domain)
porttls=443
path="/vless"
userconf="/etc/xray/vless-$user.json"

# Buat config
cat > $userconf <<EOF
{
  "clients": [
    {
      "id": "$uuid",
      "flow": "xtls-rprx-direct",
      "email": "$user"
    }
  ]
}
EOF

# Tambahkan client ke config utama (jika perlu bisa parsing json dinamis)
echo "$user $exp" >> /etc/xray/akun-vless.conf

mkdir -p /etc/xray/quota /etc/xray/iplimit
let "bytes = $kuota * 1024 * 1024 * 1024"
echo "$bytes" > /etc/xray/quota/$user
echo "$iplimit" > /etc/xray/iplimit/$user

# Restart Xray
systemctl restart xray

# Generate link
link="vless://$uuid@$domain:$porttls?encryption=none&security=tls&sni=$domain&type=ws&host=$domain&path=$path#$user"

# Output
clear
echo "===== VLESS ACCOUNT CREATED ====="
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
