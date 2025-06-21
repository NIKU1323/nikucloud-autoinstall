#!/bin/bash
clear
echo "======== CREATE TROJAN ACCOUNT ========"
read -p "Username        : " user
read -p "Masa aktif (hari): " masaaktif
read -p "Limit IP         : " iplimit
read -p "Limit Kuota (GB) : " kuota

uuid=$(cat /proc/sys/kernel/random/uuid)
exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
domain=$(cat /etc/xray/domain)
porttls=443
password=$uuid

# Simpan info user
echo "$user $exp" >> /etc/xray/akun-trojan.conf
mkdir -p /etc/xray/quota /etc/xray/iplimit
let "bytes = $kuota * 1024 * 1024 * 1024"
echo "$bytes" > /etc/xray/quota/$user
echo "$iplimit" > /etc/xray/iplimit/$user

# Restart service
systemctl restart xray

# Link
link="trojan://${password}@${domain}:${porttls}?sni=${domain}&type=ws&security=tls&host=${domain}&path=/trojan#$user"

# Output
clear
echo "===== TROJAN ACCOUNT CREATED ====="
echo "Username : $user"
echo "Expired  : $exp"
echo "Domain   : $domain"
echo "Port TLS : $porttls"
echo "Password : $password"
echo "Limit IP : $iplimit"
echo "Kuota GB : $kuota"
echo "Link     :"
echo "$link"
echo "=================================="
echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
menu
