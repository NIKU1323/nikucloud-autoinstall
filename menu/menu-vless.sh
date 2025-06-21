#!/bin/bash
# VLESS MENU - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-vless.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│           VLESS ACCOUNT MANAGER         │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "│  1. Create Vless Account"
echo -e "│  2. Trial Vless Account"
echo -e "│  3. Renew Vless Account"
echo -e "│  4. Delete Vless Account"
echo -e "│  5. Check Vless Login"
echo -e "│  6. List Vless Member"
echo -e "│  7. Delete Expired Vless"
echo -e "│  8. Backup Vless Config"
echo -e "│  9. Restore Vless Config"
echo -e "│ 10. ComeBack Menu"
echo -e "└──────────────────────────────────────────┘${NC}"
echo -ne "${YELLOW}Select From Options [ 1 - 10 ] : ${NC}"
read opt

case $opt in
  1)
    bash /root/menu/vless/create.sh ;;
  2)
    bash /root/menu/vless/trial.sh ;;
  3)
    bash /root/menu/vless/renew.sh ;;
  4)
    bash /root/menu/vless/delete.sh ;;
  5)
    bash /root/menu/vless/cek-login.sh ;;
  6)
    bash /root/menu/vless/list.sh ;;
  7)
    bash /root/menu/vless/delete-expired.sh ;;
  8)
    bash /root/menu/vless/backup.sh ;;
  9)
    bash /root/menu/vless/restore.sh ;;
  10)
    bash /root/menu/menu.sh ;;
  *)
    echo -e "${RED}Opsi tidak tersedia.${NC}"
    sleep 1
    bash /root/menu/menu-vless.sh ;;
esac
