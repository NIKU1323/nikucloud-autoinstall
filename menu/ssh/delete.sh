#!/bin/bash
# DELETE SSH ACCOUNT - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────┐"
echo -e "│            HAPUS AKUN SSH (NIKU CLOUD)       │"
echo -e "└──────────────────────────────────────────────┘${NC}"
echo ""

read -p "Masukkan username yang ingin dihapus: " user

egrep "^$user" /etc/passwd > /dev/null
if [[ $? -eq 0 ]]; then
  userdel --force $user
  echo -e "${YELLOW}────────────────────────────────────────────${NC}"
  echo -e "  Username  : ${GREEN}$user${NC}"
  echo -e "  Status    : ${RED}BERHASIL DIHAPUS${NC}"
  echo -e "${YELLOW}────────────────────────────────────────────${NC}"
else
  echo -e "${RED}Akun dengan username '$user' tidak ditemukan.${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
