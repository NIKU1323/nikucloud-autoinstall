#!/bin/bash
# MENU TROJAN - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│            MENU MANAGER TROJAN              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo -e " ${GREEN}1.${NC}  Create TROJAN Account"
echo -e " ${GREEN}2.${NC}  Trial TROJAN Account"
echo -e " ${GREEN}3.${NC}  Renew TROJAN Account"
echo -e " ${GREEN}4.${NC}  Delete TROJAN Account"
echo -e " ${GREEN}5.${NC}  Check Login TROJAN Account"
echo -e " ${GREEN}6.${NC}  List TROJAN User"
echo -e " ${GREEN}7.${NC}  Delete User Expired"
echo -e " ${GREEN}8.${NC}  Back to Main Menu"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
read -p "Select Menu TROJAN: " tr
case $tr in
  1) bash /root/menu/trojan/create.sh ;;
  2) bash /root/menu/trojan/trial.sh ;;
  3) bash /root/menu/trojan/renew.sh ;;
  4) bash /root/menu/trojan/delete.sh ;;
  5) bash /root/menu/trojan/cek.sh ;;
  6) bash /root/menu/trojan/list.sh ;;
  7) bash /root/menu/trojan/delete-exp.sh ;;
  8) bash /root/menu/menu.sh ;;
  *) echo -e "${RED}Invalid input!${NC}"; sleep 1; bash /root/menu/menu-trojan.sh ;;
esac
