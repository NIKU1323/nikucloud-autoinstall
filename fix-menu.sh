#!/bin/bash
# AUTO FIX MENU FILES VIA GITHUB
# By: NIKU TUNNEL / MERCURYVPN

REPO="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"
FILES=("menussh.sh" "menuvmess.sh" "menuvless.sh" "menutrojan.sh" "add-domain.sh" "menu.sh")

echo "📥 Mengunduh & memperbaiki semua file menu dari GitHub..."

for file in "${FILES[@]}"; do
  dst="/usr/bin/${file%.sh}"
  curl -s -o "$dst" "$REPO/$file"
  if [[ -f "$dst" ]]; then
    chmod +x "$dst"
    echo "✅ $file -> $dst"
  else
    echo "❌ Gagal mengunduh $file"
  fi
done

echo ""
echo "✅ Semua file menu telah diperbaiki dari GitHub."
echo "🟢 Silakan jalankan: menu"
