#!/bin/bash
# CREATE TROJAN ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             CREATE TROJAN ACCOUNT           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

read -p "Username           : " username
read -p "Masa aktif (hari)  : " days
read -p "Limit IP           : " ip_limit
read -p "Limit Kuota (GB)   : " quota_limit

[[ -z "$username" || -z "$days" ]] && echo -e "${RED}Input tidak lengkap.${NC}" && exit 1

password=$username
exp_date=$(date -d "$days days" +%Y-%m-%d)
domain=$(cat /etc/xray/domain)
tls_port="443"
non_tls_port="80"

# Tambahkan user ke config
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "password": "$password",
  "email": "$username"
}
EOF

# Simpan limit
mkdir -p /etc/limit/ip /etc/limit/trojan
echo "$ip_limit" > /etc/limit/ip/$username
echo "$((quota_limit * 1024 * 1024 * 1024))" > /etc/limit/trojan/$username

# Restart xray
systemctl restart xray

# Buat TROJAN Link TLS
trojan_tls="trojan://$password@$domain:$tls_port?security=tls&type=ws&host=$domain&path=/trojan#$username"
trojan_non="trojan://$password@$domain:$non_tls_port?security=none&type=ws&host=$domain&path=/trojan#$username"

# Output
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "     ${GREEN}NIKU TUNNEL / MERCURYVPN - TROJAN ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username     : ${YELLOW}$username${NC}"
echo -e "${GREEN}Password     : ${YELLOW}$password${NC}"
echo -e "${GREEN}Expired      : ${YELLOW}$exp_date${NC}"
echo -e "${GREEN}Domain       : ${YELLOW}$domain${NC}"
echo -e "${GREEN}Limit IP     : ${YELLOW}$ip_limit${NC}"
echo -e "${GREEN}Limit Kuota  : ${YELLOW}$quota_limit GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}TROJAN TLS    : ${NC}$trojan_tls"
echo -e "${GREEN}TROJAN NON-TLS: ${NC}$trojan_non"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
