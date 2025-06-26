#!/bin/bash
# RENEW SSH ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
RED='\e[31m'
CYAN='\e[36m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          PERPANJANG AKUN SSH               │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
read -p "Masukkan username: " username

# Cek apakah user ada
cek_user=$(getent passwd $username)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan!${NC}"
  exit 1
fi

# Tampilkan expired sekarang
exp_now=$(chage -l $username | grep "Account expires" | cut -d: -f2)
echo -e "${GREEN}Expired saat ini: ${YELLOW}$exp_now${NC}"

# Input tambahan hari
read -p "Tambah masa aktif (hari): " days
if [[ -z "$days" ]]; then
  echo -e "${RED}Input tidak valid!${NC}"
  exit 1
fi

# Hitung tanggal expired baru
exp_new=$(date -d "$days days" +"%Y-%m-%d")
usermod -e $exp_new $username

# Update ke file db
sed -i "/### $username /c\### $username $exp_new" /etc/xray/ssh-db.txt 2>/dev/null

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username      : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired Baru  : ${YELLOW}$exp_new${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
