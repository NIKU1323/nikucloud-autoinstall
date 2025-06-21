#!/bin/bash
# DELETE USER EXPIRED - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌─────────────────────────────────────────────┐"
echo -e "│         HAPUS AKUN SSH EXPIRED (NIKU)       │"
echo -e "└─────────────────────────────────────────────┘${NC}"
echo ""

total_deleted=0
today=$(date +%s)

while IFS=: read -r user pass uid gid full home shell; do
  if [[ $uid -ge 1000 && $user != "nobody" ]]; then
    exp_date=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
    if [[ $exp_date != "never" && $exp_date != "" ]]; then
      exp_seconds=$(date -d "$exp_date" +%s)
      if [[ $exp_seconds -le $today ]]; then
        userdel --force $user
        echo -e "  ${RED}Akun expired dihapus: $user (Expired: $exp_date)${NC}"
        ((total_deleted++))
      fi
    fi
  fi
done < /etc/passwd

if [[ $total_deleted -eq 0 ]]; then
  echo -e "${YELLOW}Tidak ada akun expired yang ditemukan.${NC}"
else
  echo ""
  echo -e "${GREEN}Total akun yang dihapus: $total_deleted${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
