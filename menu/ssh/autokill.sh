#!/bin/bash
# AUTO KILL MULTI-LOGIN SSH - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────┐"
echo -e "│      AUTO KILL MULTI LOGIN USER SSH         │"
echo -e "└──────────────────────────────────────────────┘${NC}"
echo ""

read -p "Masukkan limit maksimal login per user: " max
if [[ -z "$max" ]]; then
  echo -e "${RED}Limit tidak boleh kosong!${NC}"
  exit 1
fi

echo -e "${YELLOW}[!] Proses monitoring SSH berjalan setiap 5 detik...${NC}"
echo -e "User yang melebihi limit $max login akan otomatis di-kick."
echo ""

while true; do
  users=$(ps aux | grep -i sshd | grep -v grep | grep -v pts | awk '{print $1}' | sort | uniq)
  for u in $users; do
    total=$(ps aux | grep -w "$u" | grep -i sshd | grep -v grep | wc -l)
    if [[ $total -gt $max ]]; then
      echo -e "${RED}[!] $u melebihi login ($total), auto kill!${NC}"
      pkill -u "$u"
    fi
  done
  sleep 5
done
