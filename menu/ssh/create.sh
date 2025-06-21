#!/bin/bash
# CREATE SSH OVPN ACCOUNT - NIKU TUNNEL / MERCURYVPN

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}┌──────────────────────────────────────────┐"
echo -e "│         CREATE SSH OVPN ACCOUNT         │"
echo -e "└──────────────────────────────────────────┘${NC}"

read -p "Username         : " user
read -p "Password         : " pass
read -p "Masa aktif (hari): " exp
read -p "Limit IP Device  : " iplimit
read -p "Limit Kuota (GB) : " quotalimit

# Validasi
[[ -z "$user" || -z "$pass" || -z "$exp" ]] && echo -e "${RED}Input tidak lengkap!${NC}" && exit 1

# Konversi GB ke byte
limit_bytes=$((quotalimit * 1024 * 1024 * 1024))

# Buat akun
useradd -e $(date -d "$exp days" +"%Y-%m-%d") -s /bin/false -M "$user"
echo "$user:$pass" | chpasswd

# Simpan data limit
mkdir -p /etc/niku/ssh
echo "$iplimit" > /etc/niku/ssh/limitip-$user
echo "$limit_bytes" > /etc/niku/ssh/quota-$user

# Info detail akun
IP=$(curl -s ipv4.icanhazip.com)
domain=$(cat /etc/niku/domain)
expdate=$(chage -l $user | grep "Account expires" | awk -F": " '{print $2}')
createdate=$(date +"%d-%m-%Y")
expired=$(date -d "$exp days" +"%d-%m-%Y")

# Output akun
echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "         ${GREEN}SSH OVPN ACCOUNT${NC}"
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
echo -e "Save Link Account: /etc/niku/ssh/$user.txt"
echo -e "Aktif Selama     : $exp Hari"
echo -e "Dibuat Pada      : $createdate"
echo -e "Berakhir Pada    : $expired"
echo -e "${YELLOW}────────────────────────────────────────────${NC}"
echo -e "SC BY ${GREEN}NIKU CLOUD${NC}"

# Simpan akun ke file
mkdir -p /etc/niku/ssh
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
read -n 1 -s -r -p "Press any key to back to menu..."
/root/menu/menu-ssh.sh
