#!/bin/bash
# AUTOKILL SSH MULTILOGIN - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        AUTO KILL MULTILOGIN SSH      ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Set maksimal IP login SSH per user"
echo -e "Contoh: 2 berarti maksimal 2 IP aktif"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Maksimal IP per user: " max

if [[ -z $max ]]; then
  echo -e "${RED}Batas maksimal tidak valid.${NC}"
  exit 1
fi

cat <<EOF >/etc/cron.d/autokill
*/1 * * * * root /usr/bin/autokill
EOF

cat <<EOF >/usr/bin/autokill
#!/bin/bash
data=(\$(cat /etc/passwd | grep "/home" | cut -d: -f1))
for user in "\${data[@]}"; do
  count=\$(netstat -anp | grep ESTABLISHED | grep sshd | grep "pts" | awk '{print \$7}' | grep -w "\$user" | wc -l)
  if [[ \${count} -gt $max ]]; then
    pkill -u \$user
    echo "User \$user melebihi batas login. Koneksi dihentikan."
  fi
done
EOF

chmod +x /usr/bin/autokill
service cron restart

echo -e "${YELLOW}Autokill aktif. Setiap user dibatasi maksimal ${RED}$max${YELLOW} IP login.${NC}"
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali..."
bash /root/menu/menu-ssh.sh
