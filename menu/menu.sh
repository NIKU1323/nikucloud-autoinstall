#!/bin/bash

# Warna
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
NC="\033[0m"

# Informasi sistem
OS=$(grep "PRETTY_NAME" /etc/os-release | cut -d '=' -f2 | tr -d '"')
CORE=$(nproc)
RAM=$(free -m | awk '/Mem:/ { printf("%s/%s MB", $3, $2) }')
UPTIME=$(uptime -p | sed 's/up //')
DOMAIN=$(cat /etc/domain 2>/dev/null)
IPVPS=$(curl -s ipv4.icanhazip.com)
ISP=$(curl -s ipinfo.io/org | cut -d " " -f2-)
CITY=$(curl -s ipinfo.io/city)

# Baca lisensi
LISENSI_FILE="$HOME/license/iplist.txt"
if [ ! -f "$LISENSI_FILE" ]; then
    echo -e "${RED}❌ File lisensi tidak ditemukan!${NC}"
    exit 1
fi

DATA=$(grep "^$IPVPS|" "$LISENSI_FILE")
if [ -z "$DATA" ]; then
    echo -e "${RED}❌ IP $IPVPS belum terdaftar lisensi!${NC}"
    exit 1
fi

ID=$(echo "$DATA" | cut -d '|' -f 2)
EXP=$(echo "$DATA" | cut -d '|' -f 3)
AUTH=$(echo "$DATA" | cut -d '|' -f 4)

# Validasi masa aktif
EXP_DATE=$(date -d "$EXP" +%s)
TODAY_DATE=$(date +%s)
DAYS_LEFT=$(( ($EXP_DATE - $TODAY_DATE) / 86400 ))

if [ "$DAYS_LEFT" -lt 0 ]; then
    echo -e "${RED}❌ Masa aktif lisensi telah habis!${NC}"
    exit 1
fi

# Hitung akun aktif
ssh_count=$(grep -c "^###" /etc/xray/ssh 2>/dev/null || echo 0)
vmess_count=$(grep -c "^###" /etc/xray/vmess.json 2>/dev/null || echo 0)
vless_count=$(grep -c "^###" /etc/xray/vless.json 2>/dev/null || echo 0)
trojan_count=$(grep -c "^###" /etc/xray/trojan.json 2>/dev/null || echo 0)
shadow_count=$(grep -c "^###" /etc/xray/shadowsocks.json 2>/dev/null || echo 0)

# Status service
status_service() {
    systemctl is-active --quiet $1 && echo -e "${GREEN}●${NC}" || echo -e "${RED}○${NC}"
}

nginx_status=$(status_service nginx)
xray_status=$(status_service xray)
dropbear_status=$(status_service dropbear)
haproxy_status=$(status_service haproxy)

# Bandwidth
vnstat_daily=$(vnstat --oneline 2>/dev/null | awk -F ';' '{print $4}')
vnstat_yday=$(vnstat --oneline 2>/dev/null | awk -F ';' '{print $5}')
vnstat_month=$(vnstat -m 2>/dev/null | awk 'NR==5 {print $9" "$10}')

clear

# Tampilan
echo -e "${RED}:::. ZE-VPN STORE TUNNEL .:::${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${CYAN}System OS     =${NC} $OS"
echo -e " ${CYAN}Core System   =${NC} $CORE"
echo -e " ${CYAN}Server RAM    =${NC} $RAM"
echo -e " ${CYAN}Uptime Server =${NC} $UPTIME"
echo -e " ${CYAN}Domain        =${NC} $DOMAIN"
echo -e " ${CYAN}IP VPS        =${NC} $IPVPS"
echo -e " ${CYAN}ISP           =${NC} $ISP"
echo -e " ${CYAN}City          =${NC} $CITY"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   SSH/OPENVPN       ➤ $ssh_count  ACCOUNT PREMIUM"
echo -e "   VMESS/WS/GRPC     ➤ $vmess_count  ACCOUNT PREMIUM"
echo -e "   VLESS/WS/GRPC     ➤ $vless_count  ACCOUNT PREMIUM"
echo -e "   TROJAN/WS/GRPC    ➤ $trojan_count  ACCOUNT PREMIUM"
echo -e "   SHADOWSOCKS/WS    ➤ $shadow_count  ACCOUNT PREMIUM"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "   SSH : $nginx_status   NGINX : $nginx_status   XRAY : $xray_status\n"
printf "   WS-ePRO : $xray_status   DROPBEAR : $dropbear_status   HAPROXY : $haproxy_status\n"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Menu
cat <<EOF
[01] SSH             [06] SYSTEM
[02] VMESS           [07] BANDWIDTH
[03] VLESS           [08] SPEEDTEST
[04] TROJAN          [09] LIMIT SPD
[05] SHADOWSOCKS     [10] BACKUP

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF

# Bandwidth
echo -e " Total     Daily        Y'day        Monthly"
echo -e " ---       $vnstat_daily    $vnstat_yday     $vnstat_month"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Version       = Limited Edition"
echo -e " ID            = $ID"
echo -e " Script Status = ${GREEN}(Active)${NC}"
echo -e " Exp Script    = $EXP ($DAYS_LEFT Days Left)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Pilihan
read -p "Select Menu: " opt
case $opt in
  1) clear; bash /root/menu/menu-ssh.sh ;;
  2) clear; bash /root/menu/menu-vmess.sh ;;
  3) clear; bash /root/menu/menu-vless.sh ;;
  4) clear; bash /root/menu/menu-trojan.sh ;;
  5) clear; bash /root/menu/menu-shadow.sh ;;
  6) clear; bash /root/menu/menu-system.sh ;;
  7) clear; bash /root/menu/menu-bandwidth.sh ;;
  8) clear; bash /root/menu/menu-speedtest.sh ;;
  9) clear; bash /root/menu/menu-limit.sh ;;
 10) clear; bash /root/menu/menu-backup.sh ;;
  x|X) exit ;;
  *) echo -e "${RED}❌ Pilihan tidak valid!${NC}"; sleep 1; bash /root/menu/menu.sh ;;
esac

