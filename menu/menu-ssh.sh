#!/bin/bash
clear
echo "=========== CREATE SSH ACCOUNT ==========="
read -p "Username        : " username
read -p "Masa aktif (hari): " masaaktif
read -p "Limit IP         : " iplimit
read -p "Limit Kuota (GB) : " kuota

exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Buat user dan set expired
useradd -e $exp -s /bin/false -M $username
echo "$username:1" | chpasswd

# Simpan info akun
echo "$username $exp" >> /etc/ssh/akun.conf

# Konversi kuota ke byte
let "bytes = $kuota * 1024 * 1024 * 1024"
echo "$bytes" > /etc/ssh/quota/$username

# Simpan limit IP
echo "$iplimit" > /etc/ssh/iplimit/$username

# Tampilkan info
clear
echo "===== SSH ACCOUNT CREATED ====="
echo "Username : $username"
echo "Password : 1"
echo "Expired  : $exp"
echo "Kuota    : ${kuota}GB"
echo "Max IP   : $iplimit"
echo "==============================="
echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
menu
