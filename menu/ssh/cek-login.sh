#!/bin/bash
# CEK LOGIN SSH - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐"
echo -e "│         CEK LOGIN USER SSH ACTIVE       │"
echo -e "└──────────────────────────────────────────┘${NC}"
echo ""

# === CEK DROPBEAR ===
echo -e "${YELLOW}[ DROPBEAR LOGIN ]${NC}"
dbps=$(ps aux | grep -i dropbear | grep "Dropbear" | awk '{print $2}')
if [[ -z "$dbps" ]]; then
    echo -e "Tidak ada user login via dropbear"
else
    for pid in $dbps; do
        user=$(ps -p $pid -o args= | awk '{print $3}')
        echo -e "User  : ${GREEN}$user${NC} (via Dropbear)"
    done
fi
echo ""

# === CEK OPENSSH ===
echo -e "${YELLOW}[ OPENSSH LOGIN ]${NC}"
osh=$(who | grep "pts" | awk '{print $1}')
if [[ -z "$osh" ]]; then
    echo -e "Tidak ada user login via OpenSSH"
else
    for user in $osh; do
        echo -e "User  : ${GREEN}$user${NC} (via OpenSSH)"
    done
fi
echo ""

# === CEK WS STUNNEL ===
echo -e "${YELLOW}[ SSH WEBSOCKET LOGIN ]${NC}"
ps -ef | grep -i "ws-server" | grep -v "grep" > /dev/null
if [[ $? -ne 0 ]]; then
    echo -e "Tidak ada login WebSocket terdeteksi"
else
    netstat -anp | grep ESTABLISHED | grep tcp | grep "ws-server" | awk '{print $5}' | cut -d: -f1 | sort | uniq | while read ip
    do
        echo -e "IP Login WS : ${GREEN}$ip${NC}"
    done
fi
echo ""

echo -e "${GREEN}Selesai menampilkan login aktif${NC}"
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
