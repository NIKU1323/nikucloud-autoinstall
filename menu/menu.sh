#!/bin/bash
# MENU DASHBOARD - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[1;97m'       # putih cerah + tebal untuk frame & garis
MAGENTA='\e[35m'
WHITE_BOLD='\e[1;97m'  # putih cerah + tebal untuk teks utama

# Info Sistem
domain=$(cat /etc/xray/domain)
ip_vps=$(curl -s ipv4.icanhazip.com)
os_name=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release)
ram_total=$(free -m | awk '/^Mem:/{print $2}')
ram_used=$(free -m | awk '/^Mem:/{print $3}')
uptime_sys=$(uptime -p | cut -d " " -f2-)
core=$(nproc)
isp=$(curl -s ipinfo.io/org | cut -d " " -f2-)
city=$(curl -s ipinfo.io/city)

# Status Layanan
status_ssh=$(systemctl is-active ssh | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
status_xray=$(systemctl is-active xray | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
status_nginx=$(systemctl is-active nginx | grep -q active && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")

# Hitung jumlah akun (jika ada file JSON / conf)
ssh_count=$(grep -c '^### ' /etc/xray/ssh-db.txt 2>/dev/null || echo 0)
vmess_count=$(grep -c '^### ' /etc/xray/vmess.json 2>/dev/null || echo 0)
vless_count=$(grep -c '^### ' /etc/xray/vless.json 2>/dev/null || echo 0)
trojan_count=$(grep -c '^### ' /etc/xray/trojan.json 2>/dev/null || echo 0)

clear
echo -e "${CYAN}────────────────────────────────────────────────────"
echo -e "         .::::. ${YELLOW}NIKU TUNNEL / MERCURYVPN${CYAN} .::::."
echo -e "────────────────────────────────────────────────────${NC}"
echo -e "${WHITE_BOLD} ┌────────────────────────────────────────────┐${NC}"
echo -e "${WHITE_BOLD} │ SYS OS : ${MAGENTA}$os_name${WHITE_BOLD}"
echo -e " │ RAM    : ${MAGENTA}${ram_used}MB / ${ram_total}MB${WHITE_BOLD}"
echo -e " │ UPTIME : ${MAGENTA}$uptime_sys${WHITE_BOLD}"
echo -e " │ CORE   : ${MAGENTA}$core${WHITE_BOLD}"
echo -e " │ ISP    : ${MAGENTA}$isp${WHITE_BOLD}"
echo -e " │ CITY   : ${MAGENTA}$city${WHITE_BOLD}"
echo -e " │ IP     : ${MAGENTA}$ip_vps${WHITE_BOLD}"
echo -e " │ DOMAIN : ${MAGENTA}$domain${WHITE_BOLD}"
echo -e " └────────────────────────────────────────────┘${NC}"
echo -e "${WHITE_BOLD} ┌────────────────────────────────────────────────┐${NC}"
echo -e " │ SSH-WS : $status_ssh │ XRAY : $status_xray │ NGINX : $status_nginx │  ${GREEN}GOOD${NC} │"
echo -e " └────────────────────────────────────────────────┘"
echo -e "                 SSH OVPN : ${MAGENTA}$ssh_count${NC}"
echo -e "                 VMESS    : ${MAGENTA}$vmess_count${NC}"
echo -e "                 VLESS    : ${MAGENTA}$vless_count${NC}"
echo -e "                 TROJAN   : ${MAGENTA}$trojan_count${NC}"
echo -e "${CYAN} ┌────────────────────────────────────────────────┐${NC}"
echo -e " │ ${MAGENTA}1.${WHITE_BOLD} SSH MANAGER         ${MAGENTA}5.${WHITE_BOLD} OTHER SETTINGS        │"
echo -e " │ ${MAGENTA}2.${WHITE_BOLD} VMESS MANAGER       ${MAGENTA}6.${WHITE_BOLD} REBOOT VPS            │"
echo -e " │ ${MAGENTA}3.${WHITE_BOLD} VLESS MANAGER       ${MAGENTA}x.${WHITE_BOLD} EXIT                  │"
echo -e " │ ${MAGENTA}4.${WHITE_BOLD} TROJAN MANAGER                               │"
echo -e "${CYAN} └────────────────────────────────────────────────┘${NC}"
read -p "$(echo -e ${MAGENTA}Select Menu:${NC} )" opt
case $opt in
  1) clear; bash /root/menu/menu-ssh.sh ;;
  2) clear; bash /root/menu/menu-vmess.sh ;;
  3) clear; bash /root/menu/menu-vless.sh ;;
  4) clear; bash /root/menu/menu-trojan.sh ;;
  5) clear; bash /root/menu/menu-tools.sh ;;
  6) reboot ;;
  x) exit ;;
  *) bash /root/menu/menu.sh ;;
esac
