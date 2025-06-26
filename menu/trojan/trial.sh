#!/bin/bash
# TRIAL TROJAN ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              TRIAL TROJAN ACCOUNT           │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

username="trialtrojan$(tr -dc a-z0-9 </dev/urandom | head -c4)"
password="$username"
exp_date=$(date -d "1 days" +%Y-%m-%d)
domain=$(cat /etc/xray/domain)
tls_port="443"
non_tls_port="80"

# Tambah ke config
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "password": "$password",
  "email": "$username"
}
EOF

# Simpan limit
mkdir -p /etc/limit/ip /etc/limit/trojan
echo "1" > /etc/limit/ip/$username
echo "$((1 * 1024 * 1024 * 1024))" > /etc/limit/trojan/$username

# Restart Xray
systemctl restart xray

# Buat TROJAN Link
trojan_tls="trojan://$password@$domain:$tls_port?security=tls&type=ws&host=$domain&path=/trojan#$username"
trojan_non="trojan://$password@$domain:$non_tls_port?security=none&type=ws&host=$domain&path=/trojan#$username"

# Output
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   ${GREEN}NIKU TUNNEL / MERCURYVPN - TRIAL TROJAN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username     : ${YELLOW}$username${NC}"
echo -e "${GREEN}Password     : ${YELLOW}$password${NC}"
echo -e "${GREEN}Expired      : ${YELLOW}$exp_date${NC}"
echo -e "${GREEN}Domain       : ${YELLOW}$domain${NC}"
echo -e "${GREEN}Limit IP     : ${YELLOW}1${NC}"
echo -e "${GREEN}Limit Kuota  : ${YELLOW}1 GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}TROJAN TLS    : ${NC}$trojan_tls"
echo -e "${GREEN}TROJAN NON-TLS: ${NC}$trojan_non"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
