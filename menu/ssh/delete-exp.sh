#!/bin/bash
# DELETE EXPIRED SSH USER - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
RED='\e[31m'
CYAN='\e[36m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│        DELETE EXPIRED SSH ACCOUNTS         │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

today=$(date +%Y-%m-%d)
total_del=0

if [[ ! -f /etc/xray/ssh-db.txt ]]; then
  echo -e "${RED}Database SSH tidak ditemukan.${NC}"
  exit 1
fi

while read line; do
  user=$(echo $line | cut -d ' ' -f2)
  exp=$(echo $line | cut -d ' ' -f3)

  if [[ "$exp" < "$today" ]]; then
    userdel --force $user 2>/dev/null
    sed -i "/### $user /d" /etc/xray/ssh-db.txt
    rm -f /etc/limit/ip/$user
    rm -f /etc/limit/ssh/$user
    echo -e "${YELLOW}➤ Deleted: $user (expired $exp)${NC}"
    ((total_del++))
  fi
done < /etc/xray/ssh-db.txt

echo -e "${CYAN}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}Total akun expired yang dihapus: ${YELLOW}$total_del${NC}"
