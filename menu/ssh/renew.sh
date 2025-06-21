#!/bin/bash
# RENEW SSH ACCOUNT - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────┐"
echo -e "│           RENEW SSH ACCOUNT (NIKU CLOUD)     │"
echo -e "└──────────────────────────────────────────────┘${NC}"
echo ""

read -p "Masukkan username yang ingin diperpanjang: " user
egrep "^$user" /etc/passwd > /dev/null
if [[ $? -eq 0 ]]; then
  read -p "Perpanjang berapa hari?: " masaaktif
  today=$(date +%Y-%m-%d)
  expire=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
  exp2=$(date -d "$expire" +%s)
  today2=$(date -d "$today" +%s)
  exp_days=$(( (exp2 - today2) / 86400 ))

  total=$((exp_days + masaaktif))
  new_exp=$(date -d "$total days" +"%Y-%m-%d")
  chage -E $new_exp $user

  echo ""
  echo -e "${YELLOW}────────────────────────────────────────────${NC}"
  echo -e "  Username        : $user"
  echo -e "  Aktif Sampai    : ${GREEN}$new_exp${NC}"
  echo -e "${YELLOW}────────────────────────────────────────────${NC}"
  echo -e "  ${GREEN}Akun berhasil diperpanjang.${NC}"
else
  echo ""
  echo -e "${RED}Akun dengan username $user tidak ditemukan!${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
