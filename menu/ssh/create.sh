#!/bin/bash
# CREATE SSH ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             CREATE SSH ACCOUNT              │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

# Input data akun
read -p "Username        : " username
read -p "Password        : " password
read -p "Masa aktif (hari): " exp_days
read -p "Limit IP        : " limit_ip
read -p "Limit Kuota (GB): " limit_quota

# Validasi input
[[ -z "$username" || -z "$password" || -z "$exp_days" ]] && echo -e "${RED}Input tidak boleh kosong!${NC}" && exit 1

# Hitung expired date
exp_date=$(date -d "$exp_days days" +"%Y-%m-%d")

# Tambahkan user
useradd -e $exp_date -s /bin/false -M $username
echo "$username:$password" | chpasswd

# Simpan ke database (opsional)
echo "### $username $exp_date $limit_ip IP $limit_quota GB" >> /etc/xray/ssh-db.txt

# Konversi kuota GB ke bytes
limit_bytes=$((limit_quota * 1024 * 1024 * 1024))
echo "$limit_bytes" > /etc/limit/ssh/${username}

# Simpan limit IP (opsional)
echo "$limit_ip" > /etc/limit/ip/${username}

# Ambil info VPS
domain=$(cat /etc/xray/domain)
ip_vps=$(curl -s ipv4.icanhazip.com)
city=$(curl -s ipinfo.io/city)
isp=$(curl -s ipinfo.io/org | cut -d " " -f2-)

# Output akun
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "         ${GREEN}NIKU TUNNEL / MERCURYVPN - SSH ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username       : ${YELLOW}$username${NC}"
echo -e "${GREEN}Password       : ${YELLOW}$password${NC}"
echo -e "${GREEN}Expired        : ${YELLOW}$exp_days Hari ($exp_date)${NC}"
echo -e "${GREEN}Limit IP       : ${YELLOW}$limit_ip${NC}"
echo -e "${GREEN}Limit Kuota    : ${YELLOW}$limit_quota GB${NC}"
echo -e "${GREEN}Domain         : ${YELLOW}$domain${NC}"
echo -e "${GREEN}Host/IP        : ${YELLOW}$ip_vps${NC}"
echo -e "${GREEN}ISP            : ${YELLOW}$isp${NC}"
echo -e "${GREEN}City           : ${YELLOW}$city${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Dropbear       : 443, 109${NC}"
echo -e "${GREEN}OpenSSH        : 22, 2253${NC}"
echo -e "${GREEN}SSL/TLS        : 443${NC}"
echo -e "${GREEN}SSH WS TLS     : 443${NC}"
echo -e "${GREEN}SSH WS Non-TLS : 80${NC}"
echo -e "${GREEN}UDP Custom     : 1-65535${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Payload SSH WS TLS (HTTP Custom):${NC}"
echo -e "GET wss://$domain/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
