#!/bin/bash
# DELETE VMESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              DELETE VMESS ACCOUNT           │${NC}"
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

# Hapus limit IP & kuota
rm -f /etc/limit/ip/$username
rm -f /etc/limit/vmess/$username

# Restart Xray
systemctl restart xray

echo -e "${GREEN}Akun VMESS ${YELLOW}$username${GREEN} berhasil dihapus.${NC}"
