#!/bin/bash
# CEK LOGIN VMESS - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        CEK LOGIN VMESS AKTIF         ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Ambil IP yang sedang aktif login dari log Xray
echo -e "${YELLOW}Daftar IP yang aktif dalam log:${NC}"
aktif=$(cat /var/log/xray/access.log | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq)

if [[ -z "$aktif" ]]; then
  echo -e "${RED}Tidak ada login aktif yang terdeteksi.${NC}"
else
  echo "$aktif"
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -ne "Tekan enter untuk kembali..."
read
bash /root/menu/menu-vmess.sh
