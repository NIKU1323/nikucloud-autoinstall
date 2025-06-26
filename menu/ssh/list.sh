#!/bin/bash
# LIST AKUN SSH - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│         DAFTAR AKUN SSH TERDAFTAR          │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

if [[ ! -s /etc/xray/ssh-db.txt ]]; then
    echo -e "${RED}Tidak ada akun SSH yang terdaftar.${NC}"
    exit 0
fi

printf "%-20s %-15s %-10s\n" "Username" "Expired" "Keterangan"
echo -e "${CYAN}──────────────────────────────────────────────${NC}"

while read line; do
  user=$(echo $line | cut -d ' ' -f2)
  exp=$(echo $line | cut -d ' ' -f3)
  echo -e "${YELLOW}$user${NC}        $exp"
done < /etc/xray/ssh-db.txt

echo -e "${CYAN}──────────────────────────────────────────────${NC}"
total=$(cat /etc/xray/ssh-db.txt | wc -l)
echo -e "${GREEN}Total akun SSH: ${YELLOW}${total}${NC}"
