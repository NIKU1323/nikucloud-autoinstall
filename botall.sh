#!/bin/bash
# install.sh - MercuryBot Docker Installer by NIKU TUNNEL / MERCURYVPN

clear
echo -e "\e[1;36m[INFO] Memulai instalasi MercuryBot berbasis Python + Docker...\e[0m"

# 1. Install Docker
apt update -y && apt install -y docker.io git curl
systemctl enable docker --now

# 2. Siapkan direktori bot
mkdir -p /root/niku-bot && cd /root/niku-bot

# 3. Dockerfile
cat <<EOF > Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install python-telegram-bot aiohttp
CMD ["python", "bot.py"]
EOF

# 4. Config
cat <<EOF > config.json
{
  "bot_token": "ISI_TOKEN_BOT"
}
EOF

# 5. File data
mkdir -p data
cat <<EOF > data/users.json
{}
EOF

cat <<EOF > data/prices.json
{
  "ssh": 334,
  "vmess": 334,
  "vless": 334,
  "trojan": 334,
  "reg_ip": 2000,
  "buyvps": 30000
}
EOF

cat <<EOF > data/servers.json
{
  "Server 1": "example.com"
}
EOF

# 6. Isi file bot.py
cat <<'EOF' > bot.py
import json, uuid, asyncio
from pathlib import Path
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ApplicationBuilder, ContextTypes, CommandHandler, CallbackQueryHandler, MessageHandler, filters

CONFIG = json.load(open("config.json"))
BOT_TOKEN = CONFIG["bot_token"]
DATA_DIR = Path("data")
DATA_DIR.mkdir(exist_ok=True)

FILES = {
  "users": DATA_DIR / "users.json",
  "prices": DATA_DIR / "prices.json",
  "servers": DATA_DIR / "servers.json"
}

for file, path in FILES.items():
  if not path.exists():
    if file == "prices":
      path.write_text(json.dumps({
        "ssh": 334, "vmess": 334, "vless": 334, "trojan": 334,
        "reg_ip": 2000, "buyvps": 30000
      }, indent=2))
    elif file == "servers":
      path.write_text(json.dumps({"Server 1": "example.com"}, indent=2))
    else:
      path.write_text(json.dumps({}, indent=2))

def load(file):
  return json.loads(FILES[file].read_text())

def save(file, data):
  FILES[file].write_text(json.dumps(data, indent=2))

USER_STATE = {}

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
  id = str(update.effective_user.id)
  users = load("users")
  if id not in users:
    users[id] = {"saldo": 0, "role": "user"}
    save("users", users)
  saldo = users[id]["saldo"]
  role = users[id]["role"]
  jumlah_user = len(users)

  uptime = int(context.application.uptime())
  h, m, s = uptime // 3600, (uptime % 3600) // 60, uptime % 60

  buttons = [
    [InlineKeyboardButton("🔐 SSH", callback_data="create_ssh"), InlineKeyboardButton("🌀 VMESS", callback_data="create_vmess")],
    [InlineKeyboardButton("📡 VLESS", callback_data="create_vless"), InlineKeyboardButton("⚡ TROJAN", callback_data="create_trojan")],
    [InlineKeyboardButton("🖥️ Registrasi IP VPS", callback_data="reg_ip")],
    [InlineKeyboardButton("💳 Topup Saldo", callback_data="topup")],
    [InlineKeyboardButton("🧾 List Akun VPN", callback_data="list_vpn")],
    [InlineKeyboardButton("❌ Hapus Akun VPN", callback_data="hapus_vpn")],
    [InlineKeyboardButton("💻 Beli VPS", callback_data="buy_vps")]
  ]
  if role == "admin":
    buttons.append([InlineKeyboardButton("🛠️ Admin Panel", callback_data="admin_panel")])

  await update.message.reply_text(
    f"🛒 *MERCURY VPN — Bot E-Commerce VPN & Digital*\n"
    f"━━━━━━━━━━━━━━━━━━━━━━\n"
    f"📈 *Statistik Toko:*\n• 👥 Pengguna: {jumlah_user}\n• ⏱️ Uptime Bot: {h}j {m}m {s}d\n"
    f"━━━━━━━━━━━━━━━━━━━━━━\n"
    f"👤 *Akun Anda:*\n• 🆔 ID: {id}\n• Role: {role}\n• Saldo: Rp{saldo}\n"
    f"━━━━━━━━━━━━━━━━━━━━━━\n"
    f"Customer Service: @mercurystore12",
    reply_markup=InlineKeyboardMarkup(buttons), parse_mode="Markdown")

async def input_step(update: Update, ctx: ContextTypes.DEFAULT_TYPE, question: str):
  id = str(update.effective_user.id)
  await update.callback_query.message.reply_text(question)
  future = asyncio.get_event_loop().create_future()
  USER_STATE[id] = future
  try:
    return await asyncio.wait_for(future, timeout=60)
  except asyncio.TimeoutError:
    del USER_STATE[id]
    await update.callback_query.message.reply_text("⏰ Waktu habis. Silakan ulangi.")
    return None

async def handle_text(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
  id = str(update.effective_user.id)
  if id in USER_STATE:
    USER_STATE[id].set_result(update.message.text.strip())
    del USER_STATE[id]

async def buat_akun(update: Update, ctx: ContextTypes.DEFAULT_TYPE, jenis: str, with_password: bool, gen_link):
  id = str(update.effective_user.id)
  users, servers, prices = load("users"), load("servers"), load("prices")
  if id not in users:
    await update.callback_query.message.reply_text("❌ Anda belum terdaftar. Ketik /start.")
    return
  domain = list(servers.values())[0]
  username = await input_step(update, ctx, f"Masukkan username untuk {jenis.upper()}:")
  if not username: return
  password = await input_step(update, ctx, "Masukkan password:") if with_password else uuid.uuid4().hex[:8]
  if not password: return
  try:
    days = int(await input_step(update, ctx, "Masukkan masa aktif (1–60 hari):"))
  except:
    return
  if not (1 <= days <= 60):
    await update.callback_query.message.reply_text("❌ Masa aktif tidak valid.")
    return
  total = prices[jenis] * days
  if users[id]["saldo"] < total:
    await update.callback_query.message.reply_text("❌ Saldo tidak cukup.")
    return
  users[id]["saldo"] -= total
  save("users", users)
  uuid_str = str(uuid.uuid4())
  link = gen_link(username, password, uuid_str, domain)
  await update.callback_query.message.reply_text(
    f"✅ Akun {jenis.upper()} berhasil dibuat\n"
    f"Server: {domain}\nUsername: {username}\nHari: {days}\nHarga: Rp{total}\nLink: {link}")

async def button_handler(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
  query = update.callback_query
  data = query.data
  await query.answer()
  if data == "create_ssh":
    await buat_akun(update, ctx, "ssh", True, lambda u, p, _, d: f"ssh://{u}:{p}@{d}:22")
  elif data == "create_vmess":
    await buat_akun(update, ctx, "vmess", False, lambda u, _, uid, d: f"vmess://{json.dumps({'v': '2', 'ps': u, 'add': d, 'port': '443', 'id': uid, 'aid': '0', 'net': 'ws', 'type': 'none', 'host': d, 'path': '/vmess', 'tls': 'tls'}).encode('utf-8').hex()}")
  elif data == "create_vless":
    await buat_akun(update, ctx, "vless", False, lambda u, _, uid, d: f"vless://{uid}@{d}:443?encryption=none&security=tls&type=ws&host={d}&path=/vless#{u}")
  elif data == "create_trojan":
    await buat_akun(update, ctx, "trojan", False, lambda u, _, uid, d: f"trojan://{uid}@{d}:443?security=tls&type=ws&host={d}&path=/trojan#{u}")
  elif data == "admin_panel":
    await query.edit_message_text("🛠️ Admin Panel:", reply_markup=InlineKeyboardMarkup([
      [InlineKeyboardButton("➕ Tambah Server VPN", callback_data="add_server"),
       InlineKeyboardButton("💳 Tambah Saldo", callback_data="tambah_saldo")],
      [InlineKeyboardButton("➖ Kurangi Saldo", callback_data="kurangi_saldo"),
       InlineKeyboardButton("🔁 Ubah Role", callback_data="ubah_role")],
      [InlineKeyboardButton("💰 Atur Harga", callback_data="atur_harga"),
       InlineKeyboardButton("📢 Broadcast", callback_data="broadcast")],
      [InlineKeyboardButton("⬅️ Kembali", callback_data="back_to_main")]
    ]))
  elif data == "back_to_main":
    await start(update, ctx)

app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
app.add_handler(CallbackQueryHandler(button_handler))
print("[INFO] MercuryBot is running...")
app.run_polling()
EOF

# 7. Build Docker dan jalankan bot
docker build -t mercurybot .
docker rm -f mercurybot 2>/dev/null
docker run -d --restart=always --name mercurybot mercurybot

# 8. Selesai
echo -e "\e[1;32m[SUKSES] MercuryBot telah dijalankan di Docker.\e[0m"
echo -e "\e[1;33m[NOTE] Ganti token bot di: /root/niku-bot/config.json\e[0m"
echo -e "\e[1;36mCek log dengan: \e[0m\e[1;33mdocker logs -f mercurybot\e[0m"
