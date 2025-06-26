#!/bin/bash
# DELETE EXPIRED TROJAN - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│         DELETE EXPIRED TROJAN USERS         │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

today=$(date +%Y-%m-%d)
total_del=0

for user in $(grep '^### ' /etc/xray/config.json | cut -d ' ' -f2); do
  exp=$(grep -w "### $user" /etc/xray/config.json | cut -d ' ' -f3)
  if [[ "$exp" < "$today" ]]; then
    sed -i "/### $user/,/},{/d" /etc/xray/config.json
    rm -f /etc/limit/ip/$user
    rm -f /etc/limit/trojan/$user
    echo -e "${YELLOW}➤ Dihapus: $user (expired $exp)${NC}"
    ((total_del++))
  fi
done

systemctl restart xray

echo -e "${CYAN}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}Total akun expired yang dihapus: ${YELLOW}$total_del${NC}"
