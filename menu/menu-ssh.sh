#!/bin/bash
# MENU SSH MANAGER - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              MENU MANAGER SSH               │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo -e " ${GREEN}1.${NC}  Create SSH Account"
echo -e " ${GREEN}2.${NC}  Trial SSH Account"
echo -e " ${GREEN}3.${NC}  Renew SSH Account"
echo -e " ${GREEN}4.${NC}  Check Login SSH Account"
echo -e " ${GREEN}5.${NC}  List Member"
echo -e " ${GREEN}6.${NC}  Delete SSH Account"
echo -e " ${GREEN}7.${NC}  Delete Expired SSH User"
echo -e " ${GREEN}8.${NC}  Auto Kill SSH User"
echo -e " ${GREEN}9.${NC}  Check MultiLogin SSH"
echo -e " ${GREEN}10.${NC} Lock SSH User"
echo -e " ${GREEN}11.${NC} Unlock SSH User"
echo -e " ${GREEN}12.${NC} Back to Main Menu"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
read -p "Select Menu SSH: " ssh
case $ssh in
  1) bash /root/menu/ssh/create.sh ;;
  2) bash /root/menu/ssh/trial.sh ;;
  3) bash /root/menu/ssh/renew.sh ;;
  4) bash /root/menu/ssh/cek.sh ;;
  5) bash /root/menu/ssh/list.sh ;;
  6) bash /root/menu/ssh/delete.sh ;;
  7) bash /root/menu/ssh/delete-exp.sh ;;
  8) bash /root/menu/ssh/autokill.sh ;;
  9) bash /root/menu/ssh/multilogin.sh ;;
  10) bash /root/menu/ssh/lock.sh ;;
  11) bash /root/menu/ssh/unlock.sh ;;
  12) bash /root/menu/menu.sh ;;
  *) echo -e "${RED}Invalid input!${NC}"; sleep 1; bash /root/menu/menu-ssh.sh ;;
esac
