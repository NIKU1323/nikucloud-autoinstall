#!/bin/bash
# DELETE EXPIRED VMESS - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        DELETE EXPIRED VMESS USER     ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

now=$(date +%Y-%m-%d)
total=0
deleted=0

if [[ ! -f /etc/xray/vmess-clients.txt ]]; then
  echo -e "${RED}Tidak ditemukan file data klien VMESS.${NC}"
else
  cat /etc/xray/vmess-clients.txt | grep -E "^### " | while read exp; do
    user=$(echo $exp | cut -d ' ' -f 2)
    expdate=$(echo $exp | cut -d ' ' -f 3)
    expstamp=$(date -d "$expdate" +%s)
    nowstamp=$(date -d "$now" +%s)
    if [[ $expstamp -le $nowstamp ]]; then
      # Hapus dari config
      sed -i "/$user\"/d" /etc/xray/config.json
      # Hapus dari list
      sed -i "/$user $expdate/d" /etc/xray/vmess-clients.txt
      echo -e "${RED}Deleted expired user: $user (Expired: $expdate)${NC}"
      ((deleted++))
    fi
    ((total++))
  done
fi

systemctl restart xray

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total akun dicek     : $total"
echo -e "Total akun dihapus   : $deleted"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
bash /root/menu/menu-vmess.sh
