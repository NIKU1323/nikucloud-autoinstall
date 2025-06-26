#!/bin/bash
# DELETE SSH ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              HAPUS AKUN SSH                 │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
read -p "Masukkan username: " username

# Cek apakah user ada
cek_user=$(getent passwd $username)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan!${NC}"
  exit 1
fi

# Hapus user
userdel --force $username > /dev/null 2>&1

# Hapus data dari database jika ada
sed -i "/### $username /d" /etc/xray/ssh-db.txt 2>/dev/null
rm -f /etc/limit/ip/$username
rm -f /etc/limit/ssh/$username

echo -e "${GREEN}Akun SSH '$username' berhasil dihapus.${NC}"
