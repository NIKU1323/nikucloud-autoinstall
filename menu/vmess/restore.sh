#!/bin/bash
# RESTORE VMESS ACCOUNTS - NIKU CLOUD

backup_file="/root/vmess-backup.json"
config="/etc/xray/config.json"

if [[ ! -f "$backup_file" ]]; then
  echo "File backup tidak ditemukan: $backup_file"
  exit 1
fi

if [[ ! -f "$config" ]]; then
  echo "Xray config tidak ditemukan!"
  exit 1
fi

# Hapus semua clients lama
sed -i '/#vmess$/,/#clients$/d' "$config"
sed -i '/"protocol": "vmess"/,/}/ s/},/},\n#vmess\n          #clients/' "$config"

# Tambahkan ulang dari backup
while IFS= read -r line; do
  email=$(echo "$line" | grep -oP '"email": *"\K[^"]+')
  uuid=$(echo "$line" | grep -oP '"uuid": *"\K[^"]+')
  exp=$(echo "$line" | grep -oP '"exp": *"\K[^"]+')

  sed -i "/#clients$/ a\          {\n            \"id\": \"$uuid\",\n            \"alterId\": 0,\n            \"email\": \"$email\"\n          },\n          #clients" "$config"
  echo "### $email $exp" >> /etc/xray/vmess-clients.txt
done < <(jq -c '.[]' "$backup_file")

systemctl restart xray
echo -e "\n✅ Restore selesai dan Xray sudah direstart."
