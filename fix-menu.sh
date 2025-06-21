#!/bin/bash
# AUTO FIX MENU FILES
# By NIKU TUNNEL / MERCURYVPN

echo "🔧 Memperbaiki semua file menu..."

FILES=("menussh.sh" "menuvmess.sh" "menuvless.sh" "menutrojan.sh" "add-domain.sh" "menu.sh")
MENUDIR="menu"

# Cek folder menu
if [[ ! -d "$MENUDIR" ]]; then
    echo "❌ Folder '$MENUDIR' tidak ditemukan!"
    exit 1
fi

# Proses salin ulang
for file in "${FILES[@]}"; do
    src="$MENUDIR/$file"
    dst="/usr/bin/${file%.sh}"

    if [[ -f "$src" ]]; then
        cp -f "$src" "$dst"
        chmod +x "$dst"
        echo "✅ $file -> $dst"
    else
        echo "❌ $src tidak ditemukan."
    fi
done

echo ""
echo "✅ Semua file menu telah diperbaiki."
echo "🟢 Silakan jalankan: menu"
