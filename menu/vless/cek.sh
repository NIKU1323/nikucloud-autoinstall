#!/bin/bash
# CEK AKUN VLESS AKTIF - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│          DAFTAR AKUN VLESS AKTIF           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

if [[ ! -f /etc/xray/config.json ]]; then
    echo -e "${RED}File config.json tidak ditemukan!${NC}"
    exit 1
fi

user_list=$(grep '^### ' /etc/xray/config.json | cut -d ' ' -f2,3)
if [[ -z "$user_list" ]]; then
    echo -e "${YELLOW}Belum ada akun VLESS terdaftar.${NC}"
else
    echo -e "${GREEN}USERNAME       EXP DATE${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    echo "$user_list" | sort
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    total=$(echo "$user_list" | wc -l)
    echo -e "${GREEN}Total Akun: ${YELLOW}$total${NC}"
fi
