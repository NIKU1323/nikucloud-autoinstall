#!/bin/bash
# UNLOCK USER SSH - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────┐"
echo -e "│             BUKA KUNCI USER SSH              │"
echo -e "└──────────────────────────────────────────────┘${NC}"
echo ""

read -p "Masukkan username yang ingin dibuka kuncinya: " user

# Periksa apakah user ada
egrep "^$user" /etc/passwd > /dev/null
if [[ $? -eq 0 ]]; then
  passwd -u $user &>/dev/null
  echo -e "${YELLOW}───────────────────────────────────────────────${NC}"
  echo -e "  Username   : ${GREEN}$user${NC}"
  echo -e "  Status     : ${GREEN}DIBUKA (UNLOCKED)${NC}"
  echo -e "${YELLOW}───────────────────────────────────────────────${NC}"
else
  echo -e "${RED}User '$user' tidak ditemukan di sistem.${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
