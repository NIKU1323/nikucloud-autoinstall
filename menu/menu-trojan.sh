#!/bin/bash
# TROJAN MENU - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-trojan.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          TROJAN ACCOUNT MANAGER         │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "│  1. Create Trojan Account"
echo -e "│  2. Trial Trojan Account"
echo -e "│  3. Renew Trojan Account"
echo -e "│  4. Delete Trojan Account"
echo -e "│  5. Check Trojan Login"
echo -e "│  6. List Trojan Member"
echo -e "│  7. Delete Expired Trojan"
echo -e "│  8. Backup Trojan Config"
echo -e "│  9. Restore Trojan Config"
echo -e "│ 10. ComeBack Menu"
echo -e "└──────────────────────────────────────────┘${NC}"
echo -ne "${YELLOW}Select From Options [ 1 - 10 ] : ${NC}"
read opt

case $opt in
  1)
    bash /root/menu/trojan/create.sh ;;
  2)
    bash /root/menu/trojan/trial.sh ;;
  3)
    bash /root/menu/trojan/renew.sh ;;
  4)
    bash /root/menu/trojan/delete.sh ;;
  5)
    bash /root/menu/trojan/cek-login.sh ;;
  6)
    bash /root/menu/trojan/list.sh ;;
  7)
    bash /root/menu/trojan/delete-expired.sh ;;
  8)
    bash /root/menu/trojan/backup.sh ;;
  9)
    bash /root/menu/trojan/restore.sh ;;
  10)
    bash /root/menu/menu.sh ;;
  *)
    echo -e "${RED}Opsi tidak tersedia.${NC}"
    sleep 1
    bash /root/menu/menu-trojan.sh ;;
esac
