#!/bin/bash
# VMESS MENU - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-vmess.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│           VMESS ACCOUNT MANAGER         │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "│  1. Create Vmess Account"
echo -e "│  2. Trial Vmess Account"
echo -e "│  3. Renew Vmess Account"
echo -e "│  4. Delete Vmess Account"
echo -e "│  5. Check Vmess Login"
echo -e "│  6. List Vmess Member"
echo -e "│  7. Delete Expired Vmess"
echo -e "│  8. Backup Vmess Config"
echo -e "│  9. Restore Vmess Config"
echo -e "│ 10. ComeBack Menu"
echo -e "└──────────────────────────────────────────┘${NC}"
echo -ne "${YELLOW}Select From Options [ 1 - 10 ] : ${NC}"
read opt

case $opt in
  1)
    bash /root/menu/vmess/create.sh ;;
  2)
    bash /root/menu/vmess/trial.sh ;;
  3)
    bash /root/menu/vmess/renew.sh ;;
  4)
    bash /root/menu/vmess/delete.sh ;;
  5)
    bash /root/menu/vmess/cek-login.sh ;;
  6)
    bash /root/menu/vmess/list.sh ;;
  7)
    bash /root/menu/vmess/delete-expired.sh ;;
  8)
    bash /root/menu/vmess/backup.sh ;;
  9)
    bash /root/menu/vmess/restore.sh ;;
  10)
    bash /root/menu/menu.sh ;;
  *)
    echo -e "${RED}Opsi tidak tersedia.${NC}"
    sleep 1
    bash /root/menu/menu-vmess.sh ;;
esac
