#!/bin/bash
# RENEW VMESS ACCOUNT - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}          RENEW AKUN VMESS            ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Tampilkan list akun
grep -E "^### " /etc/xray/vmess-clients.txt | cut -d ' ' -f 2
echo -ne "\nMasukkan username yang akan diperpanjang: "
read user

# Validasi user
akun=$(grep -w "^### $user" /etc/xray/vmess-clients.txt)
if [[ -z $akun ]]; then
  echo -e "${RED}Akun tidak ditemukan!${NC}"
  exit 1
fi

# Input perpanjangan hari
echo -ne "Perpanjang berapa hari? : "
read extend_days

# Ambil tanggal expired saat ini
exp_old=$(grep -w "^### $user" /etc/xray/vmess-clients.txt | awk '{print $3}')
d1=$(date -d "$exp_old" +%s)
d2=$(date -d "+$extend_days days" +%s)
exp_new=$(date -d "@$(( (d2 - $(date +%s)) + d1 ))" +"%Y-%m-%d")

# Update tanggal di file
sed -i "/^### $user /c\### $user $exp_new" /etc/xray/vmess-clients.txt

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Akun ${YELLOW}$user${NC} berhasil diperpanjang hingga ${YELLOW}$exp_new${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
systemctl restart xray
echo -ne "\nTekan enter untuk kembali..."
read
bash /root/menu/menu-vmess.sh
