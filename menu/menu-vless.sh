#!/bin/bash
# MENU VLESS - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             MENU MANAGER VLESS              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo -e " ${GREEN}1.${NC}  Create VLESS Account"
echo -e " ${GREEN}2.${NC}  Trial VLESS Account"
echo -e " ${GREEN}3.${NC}  Renew VLESS Account"
echo -e " ${GREEN}4.${NC}  Delete VLESS Account"
echo -e " ${GREEN}5.${NC}  Check Login VLESS Account"
echo -e " ${GREEN}6.${NC}  List VLESS User"
echo -e " ${GREEN}7.${NC}  Delete User Expired"
echo -e " ${GREEN}8.${NC}  Back to Main Menu"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
read -p "Select Menu VLESS: " vl
case $vl in
  1) bash /root/menu/vless/create.sh ;;
  2) bash /root/menu/vless/trial.sh ;;
  3) bash /root/menu/vless/renew.sh ;;
  4) bash /root/menu/vless/delete.sh ;;
  5) bash /root/menu/vless/cek.sh ;;
  6) bash /root/menu/vless/list.sh ;;
  7) bash /root/menu/vless/delete-exp.sh ;;
  8) bash /root/menu/menu.sh ;;
  *) echo -e "${RED}Invalid input!${NC}"; sleep 1; bash /root/menu/menu-vless.sh ;;
esac
