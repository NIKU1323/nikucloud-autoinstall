#!/bin/bash
# RENEW VLESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│            RENEW VLESS ACCOUNT              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

read -p "Masukkan username: " username
[[ -z "$username" ]] && echo -e "${RED}Username tidak boleh kosong!${NC}" && exit 1

cek_user=$(grep -w "### $username" /etc/xray/config.json)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan!${NC}"
  exit 1
fi

read -p "Perpanjang berapa hari: " extend_days
[[ -z "$extend_days" ]] && echo -e "${RED}Input hari tidak boleh kosong!${NC}" && exit 1

# Ambil tanggal expired sekarang
exp_now=$(grep -w "### $username" /etc/xray/config.json | cut -d ' ' -f3)
exp_new=$(date -d "$exp_now +$extend_days days" +%Y-%m-%d)

# Update expired
sed -i "/### $username/c\### $username $exp_new" /etc/xray/config.json

# Restart Xray
systemctl restart xray

# Output
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username     : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired Baru : ${YELLOW}$exp_new${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
