#!/bin/bash
# CEK AKUN VMESS AKTIF - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          DAFTAR AKUN VMESS AKTIF           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

total=0
if [[ -f /etc/xray/config.json ]]; then
  grep -aE "^### " /etc/xray/config.json | cut -d ' ' -f2,3 | nl
  total=$(grep -c -E "^### " /etc/xray/config.json)
else
  echo -e "${RED}Config tidak ditemukan!${NC}"
  exit 1
fi

echo -e ""
echo -e "${GREEN}Total Akun VMESS Aktif: ${YELLOW}$total${NC}"
