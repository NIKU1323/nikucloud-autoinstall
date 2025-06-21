#!/bin/bash
# SSH MENU - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-ssh.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          MENU MANAGER SSH               │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────┘${NC}"
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "│  1. Create SSH Account"
echo -e "│  2. Trial SSH Account"
echo -e "│  3. Renew SSH Account"
echo -e "│  4. Check login SSH Account"
echo -e "│  5. List Member"
echo -e "│  6. Delete Account SSH"
echo -e "│  7. Delete User Expired"
echo -e "│  8. Auto Killer SSH"
echo -e "│  9. Check User MultiLogin"
echo -e "│ 10. Lock User SSH"
echo -e "│ 11. Unlock User SSH"
echo -e "│ 12. ComeBack Menu"
echo -e "└──────────────────────────────────────────┘${NC}"
echo -ne "${YELLOW}Select From Options [ 1 - 11 or 12 ] : ${NC}"
read opt

case $opt in
  1)
    bash /root/menu/ssh/create.sh ;;
  2)
    bash /root/menu/ssh/trial.sh ;;
  3)
    bash /root/menu/ssh/renew.sh ;;
  4)
    bash /root/menu/ssh/cek-login.sh ;;
  5)
    bash /root/menu/ssh/list.sh ;;
  6)
    bash /root/menu/ssh/delete.sh ;;
  7)
    bash /root/menu/ssh/delete-expired.sh ;;
  8)
    bash /root/menu/ssh/autokill.sh ;;
  9)
    bash /root/menu/ssh/multilogin.sh ;;
  10)
    bash /root/menu/ssh/lock.sh ;;
  11)
    bash /root/menu/ssh/unlock.sh ;;
  12)
    bash /root/menu/menu.sh ;;
  *)
    echo -e "${RED}Opsi tidak tersedia.${NC}"
    sleep 1
    bash /root/menu/menu-ssh.sh ;;
esac
