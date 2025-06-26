#!/bin/bash
# TRIAL SSH - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

# Generate username random
username="trial$(tr -dc a-z0-9 </dev/urandom | head -c4)"
password="1"
exp_days="1"
exp_date=$(date -d "$exp_days days" +"%Y-%m-%d")

# Tambahkan user trial
useradd -e $exp_date -s /bin/false -M $username
echo "$username:$password" | chpasswd
echo "### $username $exp_date" >> /etc/xray/ssh-db.txt

# Ambil info VPS
domain=$(cat /etc/xray/domain)
ip_vps=$(curl -s ipv4.icanhazip.com)
city=$(curl -s ipinfo.io/city)
isp=$(curl -s ipinfo.io/org | cut -d " " -f2-)

# Output akun trial
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "      ${GREEN}NIKU TUNNEL / MERCURYVPN - TRIAL SSH${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username       : ${YELLOW}$username${NC}"
echo -e "${GREEN}Password       : ${YELLOW}$password${NC}"
echo -e "${GREEN}Expired        : ${YELLOW}$exp_days Hari ($exp_date)${NC}"
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
