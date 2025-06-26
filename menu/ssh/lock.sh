#!/bin/bash
# LOCK SSH USER - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│               KUNCI USER SSH                │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
read -p "Masukkan username yang ingin dikunci: " username

cek_user=$(getent passwd $username)
if [[ -z "$cek_user" ]]; then
  echo -e "${RED}User $username tidak ditemukan.${NC}"
  exit 1
fi

passwd -l $username > /dev/null 2>&1
echo -e "${GREEN}User ${CYAN}$username${GREEN} berhasil dikunci.${NC}"
