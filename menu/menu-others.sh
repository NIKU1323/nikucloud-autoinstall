#!/bin/bash
# OTHER SETTINGS - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu-others.sh

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m'

clear
echo -e "${CYAN}╭════════════════════════════════════════════════════╮${NC}"
echo -e "${CYAN} │          Welcome To Ekstrak Menu                   │${NC}"
echo -e "${CYAN}╰════════════════════════════════════════════════════╯${NC}"
echo -e "${GREEN}   ══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    [01] MENU NOOBZVPN"
echo -e "    [02] MENU DELL USER EXP"
echo -e "    [03] MENU AUTO REBOOT"
echo -e "    [04] MENU RESTART SERVICE"
echo -e "    [05] MENU BOT TELEGRAM"
echo -e "    [06] MENU GANTI BANNER"
echo -e "    [07] MENU RESTART BANNER"
echo -e "    [08] MENU MONITOR"
echo -e "    [09] INSTALL UDP"
echo -e "    [10] GANTI DOMAIN"
echo -e "    [11] CEK RUNNING"
echo -e "    [12] UPDATE SCRIPT"
echo -e "    [13] MENU BACKUP"
echo -e "    [14] INFO PORT"
echo -e "${GREEN}   ══════════════════════════════════════════════════${NC}"
echo -ne "${YELLOW} SELECT OPTIONS ⟩ ${NC}"
read opt

case $opt in
  1) bash /root/menu/others/noobzvpn.sh ;;
  2) bash /root/menu/others/delete-expired.sh ;;
  3) bash /root/menu/others/autoreboot.sh ;;
  4) bash /root/menu/others/restart.sh ;;
  5) bash /root/menu/others/bot.sh ;;
  6) bash /root/menu/others/banner.sh ;;
  7) bash /root/menu/others/restart-banner.sh ;;
  8) bash /root/menu/others/monitor.sh ;;
  9) bash /root/menu/others/udp.sh ;;
 10) bash /root/menu/others/add-domain.sh ;;
 11) bash /root/menu/others/cek-running.sh ;;
 12) bash /root/menu/others/update.sh ;;
 13) bash /root/menu/others/backup.sh ;;
 14) bash /root/menu/others/port-info.sh ;;
 *) echo -e "${RED} Opsi tidak tersedia.${NC}" ; sleep 1 ; bash /root/menu/menu-others.sh ;;
esac
