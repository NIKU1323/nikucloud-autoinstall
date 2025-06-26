#!/bin/bash
# UNLOCK SSH USER - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│            BUKA KUNCI USER SSH              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
read -p "Masukkan username yang ingin dibuka: " username

cek_user=$(getent passwd $username)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan.${NC}"
  exit 1
fi

passwd -u $username > /dev/null 2>&1
echo -e "${GREEN}User ${CYAN}$username${GREEN} berhasil dibuka kembali.${NC}"
