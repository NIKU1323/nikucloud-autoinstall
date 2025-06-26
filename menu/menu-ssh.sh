#!/bin/bash
# MENU SSH MANAGER - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
WHITE='\e[1;97m'
BRIGHT_WHITE='\e[1;38;5;15m'
BORDER='\e[1;38;5;245m'

clear
echo -e "${BORDER}┌──────────────────────────────────────────────┐${NC}"
echo -e "${WHITE}│              MENU MANAGER SSH               │${NC}"
echo -e "${BORDER}└──────────────────────────────────────────────┘${NC}"
echo -e " ${BRIGHT_WHITE}1.${NC}  Create SSH Account"
echo -e " ${BRIGHT_WHITE}2.${NC}  Trial SSH Account"
echo -e " ${BRIGHT_WHITE}3.${NC}  Renew SSH Account"
echo -e " ${BRIGHT_WHITE}4.${NC}  Check Login SSH Account"
echo -e " ${BRIGHT_WHITE}5.${NC}  List Member"
echo -e " ${BRIGHT_WHITE}6.${NC}  Delete SSH Account"
echo -e " ${BRIGHT_WHITE}7.${NC}  Delete Expired SSH User"
echo -e " ${BRIGHT_WHITE}8.${NC}  Auto Kill SSH User"
echo -e " ${BRIGHT_WHITE}9.${NC}  Check MultiLogin SSH"
echo -e " ${BRIGHT_WHITE}10.${NC} Lock SSH User"
echo -e " ${BRIGHT_WHITE}11.${NC} Unlock SSH User"
echo -e " ${BRIGHT_WHITE}12.${NC} Back to Main Menu"
echo -e "${BORDER}────────────────────────────────────────────────${NC}"
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
  *) echo -e "${WHITE}Invalid input!${NC}"; sleep 1; bash /root/menu/menu-ssh.sh ;;
esac
