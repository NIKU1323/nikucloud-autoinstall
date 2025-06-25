#!/bin/bash
# MENU VMESS - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             MENU MANAGER VMESS              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo -e " ${GREEN}1.${NC}  Create VMESS Account"
echo -e " ${GREEN}2.${NC}  Trial VMESS Account"
echo -e " ${GREEN}3.${NC}  Renew VMESS Account"
echo -e " ${GREEN}4.${NC}  Delete VMESS Account"
echo -e " ${GREEN}5.${NC}  Check Login VMESS Account"
echo -e " ${GREEN}6.${NC}  List VMESS User"
echo -e " ${GREEN}7.${NC}  Delete User Expired"
echo -e " ${GREEN}8.${NC}  Back to Main Menu"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
read -p "Select Menu VMESS: " vm
case $vm in
  1) bash /root/menu/vmess/create.sh ;;
  2) bash /root/menu/vmess/trial.sh ;;
  3) bash /root/menu/vmess/renew.sh ;;
  4) bash /root/menu/vmess/delete.sh ;;
  5) bash /root/menu/vmess/cek.sh ;;
  6) bash /root/menu/vmess/list.sh ;;
  7) bash /root/menu/vmess/delete-exp.sh ;;
  8) bash /root/menu/menu.sh ;;
  *) echo -e "${RED}Invalid input!${NC}"; sleep 1; bash /root/menu/menu-vmess.sh ;;
esac
