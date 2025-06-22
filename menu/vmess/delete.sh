#!/bin/bash
# DELETE AKUN VMESS - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}          HAPUS AKUN VMESS            ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Menampilkan daftar akun
echo -e "${YELLOW}Daftar akun VMESS yang tersedia:${NC}"
grep -E "^### " /etc/xray/vmess-clients.txt | cut -d ' ' -f 2

echo ""
read -p "Masukkan username yang ingin dihapus: " user

if [[ -z "$user" ]]; then
  echo -e "${RED}Username tidak boleh kosong!${NC}"
  read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
  bash /root/menu/menu-vmess.sh
  exit
fi

# Cek apakah user ada
if ! grep -q "$user" /etc/xray/vmess-clients.txt; then
  echo -e "${RED}Username tidak ditemukan!${NC}"
  read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
  bash /root/menu/menu-vmess.sh
  exit
fi

# Hapus dari config.json
sed -i "/#vmess$/,/#clients$/ {
  :a
  N
  /\"email\": \"$user\"/ {
    N
    N
    d
  }
  ta
}" /etc/xray/config.json

# Hapus dari file clients
sed -i "/### $user /d" /etc/xray/vmess-clients.txt

systemctl restart xray
echo -e "${GREEN}Akun VMESS [$user] berhasil dihapus.${NC}"
read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
bash /root/menu/menu-vmess.sh
