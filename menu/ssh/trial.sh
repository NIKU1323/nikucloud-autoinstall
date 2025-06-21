#!/bin/bash
# TRIAL SSH ACCOUNT - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐"
echo -e "│             TRIAL SSH ACCOUNT            │"
echo -e "└──────────────────────────────────────────┘${NC}"

user="trial$(tr -dc a-z0-9 </dev/urandom | head -c4)"
pass="1"
exp="1"
iplimit="1"
quotalimit="1"

# Buat user trial
useradd -e $(date -d "$exp days" +"%Y-%m-%d") -s /bin/false -M "$user"
echo "$user:$pass" | chpasswd

# Simpan limit
mkdir -p /etc/niku/ssh
echo "$iplimit" > /etc/niku/ssh/limitip-$user
echo $((quotalimit * 1024 * 1024 * 1024)) > /etc/niku/ssh/quota-$user

# Info akun
domain=$(cat /etc/niku/domain)
IP=$(curl -s ipv4.icanhazip.com)
createdate=$(date +"%d-%m-%Y")
expired=$(date -d "$exp days" +"%d-%m-%Y")

echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "         ${GREEN}TRIAL SSH OVPN ACCOUNT${NC}"
echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "Username         : $user"
echo -e "Password         : $pass"
echo -e "Host             : $domain"
echo -e "Port OpenSSH     : 443, 80, 22"
echo -e "Port Dropbear    : 443, 109"
echo -e "Port SSH WS      : 80, 8080, 8081-9999"
echo -e "Port SSH SSL WS  : 443"
echo -e "Port SSL/TLS     : 400-900"
echo -e "Port OVPN WS SSL : 443"
echo -e "Port OVPN SSL    : 443"
echo -e "Port OVPN TCP    : 443, 1194"
echo -e "Port OVPN UDP    : 2200"
echo -e "BadVPN UDP       : 7100, 7300, 7300"
echo -e "Format Hc        : ssh://$user@$domain:443"
echo -e "Payload WSS      : GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
echo -e "OVPN Download    : http://$domain:80/"
echo -e "Aktif Selama     : $exp Hari"
echo -e "Dibuat Pada      : $createdate"
echo -e "Berakhir Pada    : $expired"
echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "SC BY ${GREEN}NIKU CLOUD${NC}"

# Simpan link
cat <<EOF > /etc/niku/ssh/$user.txt
Username         : $user
Password         : $pass
Host             : $domain
Port OpenSSH     : 443, 80, 22
Port Dropbear    : 443, 109
Port SSH WS      : 80, 8080, 8081-9999
Port SSH SSL WS  : 443
Port SSL/TLS     : 400-900
Port OVPN WS SSL : 443
Port OVPN SSL    : 443
Port OVPN TCP    : 443, 1194
Port OVPN UDP    : 2200
BadVPN UDP       : 7100, 7300, 7300
Format Hc        : ssh://$user@$domain:443
Payload WSS      : GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]
OVPN Download    : http://$domain:80/
Aktif Selama     : $exp Hari
Dibuat Pada      : $createdate
Berakhir Pada    : $expired
SC BY NIKU CLOUD
EOF

echo ""
read -n 1 -s -r -p "Press any key to return to menu..."
/root/menu/menu-ssh.sh
