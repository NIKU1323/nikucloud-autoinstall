#!/bin/bash
# CEK LOGIN SSH - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
CYAN='\e[36m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          CEK LOGIN AKTIF SSH USER           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo ""

# Ambil daftar login user aktif via service SSH, Dropbear, OpenVPN, dan SSH WS
echo -e "${YELLOW}--- OpenSSH ---${NC}"
ps -ef | grep -i "sshd" | grep -i "priv" | awk '{print $1}'

echo -e "${YELLOW}--- Dropbear ---${NC}"
ps -ef | grep -i dropbear | grep -v grep | awk '{print $1}' | while read pid; do
    user=$(ps -o user= -p $pid)
    echo "$user"
done

echo -e "${YELLOW}--- SSH WebSocket ---${NC}"
netstat -ntp | grep 80 | grep ESTABLISHED | grep ssh | awk '{print $7}' | cut -d'/' -f2

echo -e "${YELLOW}--- W (realtime login) ---${NC}"
w | awk '{print $1}' | tail -n +3 | sort | uniq

echo -e ""
echo -e "${CYAN}Note: Nama user yang muncul berarti sedang aktif login SSH.${NC}"
