#!/bin/bash
# LIST MEMBER VMESS - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}         DAFTAR MEMBER VMESS          ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ ! -s /etc/xray/vmess-clients.txt ]]; then
  echo -e "${RED}Tidak ada member VMESS ditemukan.${NC}"
else
  echo -e "${YELLOW}Username          Expired Date${NC}"
  echo -e "${YELLOW}────────────────────────────────────${NC}"
  grep -E "^### " /etc/xray/vmess-clients.txt | while read line; do
    user=$(echo $line | cut -d ' ' -f 2)
    exp=$(echo $line | cut -d ' ' -f 3)
    printf "%-18s %s\n" "$user" "$exp"
  done
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
bash /root/menu/menu-vmess.sh
