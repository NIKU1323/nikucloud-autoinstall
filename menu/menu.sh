#!/bin/bash
# MENU DASHBOARD - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

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
status_ssh=$(systemctl is-active ssh | grep -q active && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}")
status_xray=$(systemctl is-active xray | grep -q active && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}")
status_nginx=$(systemctl is-active nginx | grep -q active && echo "${GREEN}ON${NC}" || echo "${RED}OFF${NC}")

# Hitung jumlah akun (jika ada file JSON / conf)
ssh_count=$(grep -c '^### ' /etc/xray/ssh-db.txt 2>/dev/null || echo 0)
vmess_count=$(grep -c '^### ' /etc/xray/vmess.json 2>/dev/null || echo 0)
vless_count=$(grep -c '^### ' /etc/xray/vless.json 2>/dev/null || echo 0)
trojan_count=$(grep -c '^### ' /etc/xray/trojan.json 2>/dev/null || echo 0)

clear
echo -e "${CYAN}────────────────────────────────────────────────────"
echo -e "         .::::. ${YELLOW}NIKU TUNNEL / MERCURYVPN${CYAN} .::::."
echo -e "────────────────────────────────────────────────────${NC}"
echo -e " ┌────────────────────────────────────────────┐"
echo -e " │ SYS OS : $os_name"
echo -e " │ RAM    : ${ram_total}MB / ${ram_used}MB"
echo -e " │ UPTIME : $uptime_sys"
echo -e " │ CORE   : $core"
echo -e " │ ISP    : $isp"
echo -e " │ CITY   : $city"
echo -e " │ IP     : $ip_vps"
echo -e " │ DOMAIN : $domain"
echo -e " └────────────────────────────────────────────┘"
echo -e " ┌────────────────────────────────────────────────┐"
echo -e " │ SSH-WS : $status_ssh │ XRAY : $status_xray │ NGINX : $status_nginx │  GOOD │"
echo -e " └────────────────────────────────────────────────┘"
echo -e "                 SSH OVPN : $ssh_count"
echo -e "                 VMESS    : $vmess_count"
echo -e "                 VLESS    : $vless_count"
echo -e "                 TROJAN   : $trojan_count"
echo -e " ┌────────────────────────────────────────────────┐"
echo -e " │ 1. SSH MANAGER         5. OTHER SETTINGS        │"
echo -e " │ 2. VMESS MANAGER       6. REBOOT VPS            │"
echo -e " │ 3. VLESS MANAGER       x. EXIT                  │"
echo -e " │ 4. TROJAN MANAGER                               │"
echo -e " └────────────────────────────────────────────────┘"
read -p "Select Menu: " opt
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

