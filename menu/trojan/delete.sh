#!/bin/bash
# DELETE TROJAN ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              DELETE TROJAN ACCOUNT          │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

read -p "Masukkan username: " username
[[ -z "$username" ]] && echo -e "${RED}Username tidak boleh kosong!${NC}" && exit 1

cek_user=$(grep -w "### $username" /etc/xray/config.json)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan!${NC}"
  exit 1
fi

# Hapus dari config
sed -i "/### $username/,/},{/d" /etc/xray/config.json

# Hapus file limit
rm -f /etc/limit/ip/$username
rm -f /etc/limit/trojan/$username

# Restart xray
systemctl restart xray

echo -e "${GREEN}Akun TROJAN ${YELLOW}$username${GREEN} berhasil dihapus.${NC}"
