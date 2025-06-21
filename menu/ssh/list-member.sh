#!/bin/bash
# LIST MEMBER SSH - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌────────────────────────────────────────────┐"
echo -e "│         LIST SEMUA MEMBER SSH (NIKU)       │"
echo -e "└────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${YELLOW}USERNAME           |  EXP DATE${NC}"
echo -e "${YELLOW}────────────────────────────────────────────${NC}"

total=0
while IFS=: read -r user pass uid gid desc home shell
do
  if [[ $uid -ge 1000 && $user != "nobody" ]]; then
    exp="$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')"
    printf "%-18s : %s\n" "$user" "$exp"
    ((total++))
  fi
done < /etc/passwd

echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "Total Akun SSH: ${GREEN}$total${NC}"
echo ""

read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
