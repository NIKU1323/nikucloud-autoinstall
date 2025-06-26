#!/bin/bash
# DELETE EXPIRED VMESS - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│         DELETE EXPIRED VMESS ACCOUNTS       │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

today=$(date +%Y-%m-%d)
total_del=0

# Ambil semua baris akun VMESS
for user in $(grep '^### ' /etc/xray/config.json | cut -d ' ' -f2); do
  exp=$(grep -w "### $user" /etc/xray/config.json | cut -d ' ' -f3)
  if [[ "$exp" < "$today" ]]; then
    # Hapus dari config.json
    sed -i "/### $user/,/},{/d" /etc/xray/config.json
    rm -f /etc/limit/ip/$user
    rm -f /etc/limit/vmess/$user
    echo -e "${YELLOW}➤ Dihapus: $user (expired $exp)${NC}"
    ((total_del++))
  fi
done

# Restart Xray
systemctl restart xray

echo -e "${CYAN}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}Total akun expired yang dihapus: ${YELLOW}$total_del${NC}"
