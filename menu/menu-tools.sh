#!/bin/bash
# MENU TOOLS / SETTINGS - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
CYAN='\e[36m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'

clear
# Baca nama client & masa aktif
client_name=$(cat /etc/niku/client.conf 2>/dev/null)
expired_date=$(cat /etc/niku/expired.conf 2>/dev/null)

[[ -z "$client_name" ]] && client_name="Belum Terdaftar"
[[ -z "$expired_date" ]] && expired_date="Tidak diketahui"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}    NAMA CLIENT  : ${YELLOW}$client_name${NC}"
echo -e "${GREEN}    EXPIRED DATE : ${YELLOW}$expired_date${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             OTHER SETTINGS & TOOLS          │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
echo -e " ${GREEN}1.${NC}  Tambah / Ganti Domain"
echo -e " ${GREEN}2.${NC}  Restart Semua Layanan"
echo -e " ${GREEN}3.${NC}  Tes Speed VPS"
echo -e " ${GREEN}4.${NC}  Info System VPS"
echo -e " ${GREEN}5.${NC}  Clear RAM Cache"
echo -e " ${GREEN}6.${NC}  Update Script"
echo -e " ${GREEN}x.${NC}  Kembali ke Menu Utama"
echo ""

read -p "Pilih menu: " opt
case $opt in
  1)
    read -p "Masukkan domain baru: " new_domain
    [[ -z "$new_domain" ]] && echo -e "${RED}Domain tidak boleh kosong!${NC}" && exit 1
    echo "$new_domain" > /etc/xray/domain
    echo "IP=$(curl -s ipv4.icanhazip.com)" > /var/lib/niku/ip.conf
    domain=$new_domain

    echo -e "${YELLOW}Menginstal ulang SSL Let's Encrypt...${NC}"
    systemctl stop nginx
    systemctl stop xray

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force
    ~/.acme.sh/acme.sh --install-cert -d $domain --fullchain-file /etc/xray/xray.crt \
      --key-file /etc/xray/xray.key --ecc --force

    chmod 600 /etc/xray/xray.key
    systemctl restart nginx
    systemctl restart xray

    echo -e "${GREEN}Domain diubah ke: ${YELLOW}$domain${NC}"
    echo -e "${GREEN}SSL berhasil di-install ulang!${NC}"
    ;;
  2)
    echo -e "${YELLOW}Restarting all services...${NC}"
    systemctl restart xray nginx ssh dropbear stunnel5 badvpn cron
    systemctl restart ws-dropbear ws-stunnel >/dev/null 2>&1
    echo -e "${GREEN}Semua layanan telah direstart.${NC}"
    ;;
  3)
    echo -e "${YELLOW}Cek & install speedtest-cli jika belum tersedia...${NC}"
    if ! command -v speedtest-cli >/dev/null 2>&1; then
      echo -e "${YELLOW}speedtest-cli belum ada, menginstall...${NC}"
      apt update -y >/dev/null 2>&1
      apt install -y speedtest-cli >/dev/null 2>&1
      echo -e "${GREEN}speedtest-cli berhasil diinstall.${NC}"
    fi
    echo -e "${YELLOW}Mengukur kecepatan internet VPS...${NC}"
    speedtest-cli
    ;;
  4)
    clear
    echo -e "${CYAN}──────────── INFO VPS ────────────${NC}"
    echo -e "IP VPS      : $(curl -s ipv4.icanhazip.com)"
    echo -e "ISP         : $(curl -s ipinfo.io/org | cut -d ' ' -f2-)"
    echo -e "City        : $(curl -s ipinfo.io/city)"
    echo -e "RAM         : $(free -m | awk 'NR==2 {print $2}') MB"
    echo -e "Uptime      : $(uptime -p)"
    echo -e "${CYAN}─────────────────────────────────${NC}"
    ;;
  5)
    echo -e "${YELLOW}Membersihkan cache RAM...${NC}"
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo -e "${GREEN}Cache RAM dibersihkan.${NC}"
    ;;
  6)
    echo -e "${YELLOW}Updating script dari repo GitHub...${NC}"
    cd /root
    rm -rf nikucloud-autoinstall
    git clone https://github.com/NIKU1323/nikucloud-autoinstall
    cp -r nikucloud-autoinstall/menu/* /root/menu/
    chmod +x /root/menu/*
    echo -e "${GREEN}Update selesai.${NC}"
    ;;
  x) bash /root/menu/menu.sh ;;
  *) echo -e "${RED}Input salah!${NC}" && sleep 1 && bash /root/menu/menu-tools.sh ;;
esac
