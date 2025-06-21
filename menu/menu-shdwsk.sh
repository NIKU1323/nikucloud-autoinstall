#!/bin/bash
# SHADOWSOCKS MENU - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-shdwsk.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│       SHADOWSOCKS ACCOUNT MANAGER       │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "│  1. Create Shadowsocks Account"
echo -e "│  2. Trial Shadowsocks Account"
echo -e "│  3. Renew Shadowsocks Account"
echo -e "│  4. Delete Shadowsocks Account"
echo -e "│  5. Check Shadowsocks Login"
echo -e "│  6. List Shadowsocks Member"
echo -e "│  7. Delete Expired Shadowsocks"
echo -e "│  8. Backup Shadowsocks Config"
echo -e "│  9. Restore Shadowsocks Config"
echo -e "│ 10. ComeBack Menu"
echo -e "└──────────────────────────────────────────┘${NC}"
echo -ne "${YELLOW}Select From Options [ 1 - 10 ] : ${NC}"
read opt

case $opt in
  1)
    bash /root/menu/shdwsk/create.sh ;;
  2)
    bash /root/menu/shdwsk/trial.sh ;;
  3)
    bash /root/menu/shdwsk/renew.sh ;;
  4)
    bash /root/menu/shdwsk/delete.sh ;;
  5)
    bash /root/menu/shdwsk/cek-login.sh ;;
  6)
    bash /root/menu/shdwsk/list.sh ;;
  7)
    bash /root/menu/shdwsk/delete-expired.sh ;;
  8)
    bash /root/menu/shdwsk/backup.sh ;;
  9)
    bash /root/menu/shdwsk/restore.sh ;;
  10)
    bash /root/menu/menu.sh ;;
  *)
    echo -e "${RED}Opsi tidak tersedia.${NC}"
    sleep 1
    bash /root/menu/menu-shdwsk.sh ;;
esac
