#!/bin/bash
# MENU UTAMA - NIKU TUNNEL / MERCURYVPN
# Lokasi file: /root/menu/menu.sh

GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m'

clear
# Informasi Sistem
DOMAIN=$(cat /etc/niku/domain)
CITY=$(curl -s ipinfo.io/city)
ISP=$(curl -s ipinfo.io/org)
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
UPTIME=$(uptime -p | cut -d " " -f2-)
CORE=$(nproc)
MYIP=$(curl -s ipv4.icanhazip.com)

# STATUS SERVICE
check_status() {
    systemctl is-active $1 &>/dev/null && echo -n "ON" || echo -n "OFF"
}
STATUS_SSH=$(check_status ssh)
STATUS_XRAY=$(check_status xray)
STATUS_NGINX=$(check_status nginx)

# Jumlah Akun
COUNT_SSH=$(ls /etc/ssh | wc -l)
COUNT_VM=$(grep -c '^###' /etc/xray/config.json)
COUNT_VL=$(grep -c '^###' /etc/xray/config.json)
COUNT_TR=$(grep -c '^###' /etc/xray/config.json)

# Tampilan Menu
clear
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo -e "             .::::. ${YELLOW}NIKU TUNNEL${NC} / ${YELLOW}MERCURYVPN${NC} .::::."
echo -e "${GREEN}───────────────────────────────────────────────────${NC}"
echo -e "       ┌────────────────────────────────────────┐"
echo -e "       │ SYS OS : $(lsb_release -d | cut -f2)"
echo -e "       │ RAM    : ${RAM_TOTAL} MB / ${RAM_USED} MB"
echo -e "       │ UP     : ${UPTIME}"
echo -e "       │ CORE   : ${CORE}"
echo -e "       │ ISP    : ${ISP}"
echo -e "       │ CITY   : ${CITY}"
echo -e "       │ IP     : ${MYIP}"
echo -e "       │ DOMAIN : ${DOMAIN}"
echo -e "       └────────────────────────────────────────┘"
echo -e "  ┌───────────────────────────────────────────────────┐"
echo -e "  │ SSH-WS : $STATUS_SSH │ XRAY : $STATUS_XRAY │ NGINX : $STATUS_NGINX │   GOOD     │"
echo -e "  └───────────────────────────────────────────────────┘"
echo -e "     ┌─────────────────────────────────────────────┐"
echo -e "     │ SCRIPT BY NIKU CLOUD"
echo -e "     └─────────────────────────────────────────────┘"
echo -e "                    SSH OVPN : ${COUNT_SSH}"
echo -e "                    VMESS    : ${COUNT_VM}"
echo -e "                    VLESS    : ${COUNT_VL}"
echo -e "                    TROJAN   : ${COUNT_TR}"
echo -e "  ┌───────────────────────────────────────────────────┐"
echo -e "  │ 1.SSH OVPN MANAGER          5.SHDWSK MANAGER      │"
echo -e "  │ 2.VMESS MANAGER             6.CEK SPEED VPS       │"
echo -e "  │ 3.VLESS MANAGER             7.FIX SERVICE         │"
echo -e "  │ 4.TROJAN MANAGER            8.OTHER SETTINGS      │"
echo -e "  └───────────────────────────────────────────────────┘"
echo -e "                     Version : 2025"
echo -e "                 ━━━━━━━━━━━━━━━━━━━━━━━"
echo -ne "${YELLOW}      Pilih menu [1-8] : ${NC}"
read pilih

case $pilih in
    1) 
        bash /root/menu/menu-ssh.sh ;;
    2)
        bash /root/menu/menu-vmess.sh ;;
    3)
        bash /root/menu/menu-vless.sh ;;
    4)
        bash /root/menu/menu-trojan.sh ;;
    5)
        bash /root/menu/menu-shadowsocks.sh ;;
    6)
        speedtest-cli ;;
    7)
        systemctl restart ssh dropbear xray nginx squid ;;
    8)
        bash /root/menu/menu-other.sh ;;
    *)
        echo -e "${RED}Pilihan tidak valid.${NC}"; sleep 1; /root/menu/menu.sh ;;
esac
