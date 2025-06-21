#!/bin/bash
# CEK USER MULTI LOGIN SSH - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────────┐"
echo -e "│          CEK USER SSH MULTI LOGIN            │"
echo -e "└──────────────────────────────────────────────┘${NC}"
echo ""

# Ambil data user SSH aktif dari who
declare -A user_count
while read -r user; do
  user_count[$user]=$(( ${user_count[$user]:-0} + 1 ))
done < <(who | awk '{print $1}')

found=0
for user in "${!user_count[@]}"; do
  if [[ ${user_count[$user]} -gt 1 ]]; then
    echo -e " ${YELLOW}- $user${NC} sedang login di ${RED}${user_count[$user]}${NC} sesi"
    found=1
  fi
done

if [[ $found -eq 0 ]]; then
  echo -e "${GREEN}[✓] Tidak ada user multi-login SSH saat ini.${NC}"
fi

echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu..."
/root/menu/menu-ssh.sh
