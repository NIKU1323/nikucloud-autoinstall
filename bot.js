// MERCURY VPN — Bot Telegram v2 (Fix Bug + Full Menu)
const { Telegraf, Markup } = require("telegraf");
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");

const bot = new Telegraf("ISI_TOKEN_BOT"); // Ganti token
const ADMIN_ID = 12345678; // Ganti ID admin utama

const dataDir = path.join(__dirname, "data");
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir);

const FILES = {
  users: path.join(dataDir, "users.json"),
  prices: path.join(dataDir, "prices.json"),
  servers: path.join(dataDir, "servers.json")
};

const load = (file) => fs.existsSync(file) ? JSON.parse(fs.readFileSync(file)) : {};
const save = (file, data) => fs.writeFileSync(file, JSON.stringify(data, null, 2));

if (!fs.existsSync(FILES.users)) save(FILES.users, {});
if (!fs.existsSync(FILES.prices)) save(FILES.prices, {
  ssh: 334,
  vmess: 334,
  vless: 334,
  trojan: 334,
  reg_ip: 2000,
  buyvps: 30000
});
if (!fs.existsSync(FILES.servers)) save(FILES.servers, {
  "Server 1": "example.com"
});

// Menyimpan status input tiap user
const userStates = {};

async function inputStep(ctx, question) {
  const id = ctx.from.id;

  await ctx.reply(question);

  return new Promise((resolve) => {
    if (userStates[id]) {
      clearTimeout(userStates[id].timeout);
    }

    userStates[id] = {
      resolve,
      timeout: setTimeout(() => {
        delete userStates[id];
        ctx.reply("⏰ Waktu habis. Silakan ulangi proses.");
      }, 60000) // timeout 60 detik
    };
  });
}

// Global listener hanya 1x
bot.on("text", (ctx) => {
  const id = ctx.from.id;
  if (userStates[id]) {
    const { resolve, timeout } = userStates[id];
    clearTimeout(timeout);
    delete userStates[id];
    resolve(ctx.message.text.trim());
  }
});

bot.start(async (ctx) => {
  const id = ctx.from.id;
  const users = load(FILES.users);
  if (!users[id]) users[id] = { saldo: 0, role: "user" };
  save(FILES.users, users);

  const uptime = process.uptime();
  const h = Math.floor(uptime / 3600);
  const m = Math.floor((uptime % 3600) / 60);
  const s = Math.floor(uptime % 60);

  await ctx.replyWithMarkdown(`🛒 *MERCURY VPN — Bot E-Commerce VPN & Digital*
━━━━━━━━━━━━━━━━━━━━━━
📈 *Statistik Toko:*
• 👥 Pengguna: ${Object.keys(users).length}
• ⏱️ Uptime Bot: ${h}j ${m}m ${s}d
━━━━━━━━━━━━━━━━━━━━━━
👤 *Akun Anda:*
• 🆔 ID: ${id}
• Username: @${ctx.from.username || "-"}
• Role: ${users[id].role}
• Saldo: Rp${users[id].saldo}
━━━━━━━━━━━━━━━━━━━━━━
Customer Service: @mercurystore12
━━━━━━━━━━━━━━━━━━━━━━`, Markup.inlineKeyboard([
    [Markup.button.callback("🔐 SSH", "create_ssh"), Markup.button.callback("🌀 VMESS", "create_vmess")],
    [Markup.button.callback("📡 VLESS", "create_vless"), Markup.button.callback("⚡ TROJAN", "create_trojan")],
    [Markup.button.callback("🖥️ Registrasi IP VPS", "reg_ip")],
    [Markup.button.callback("💳 Topup Saldo", "topup")],
    [Markup.button.callback("🧾 List Akun VPN", "list_vpn")],
    [Markup.button.callback("❌ Hapus Akun VPN", "hapus_vpn")],
    [Markup.button.callback("💻 Beli VPS", "buy_vps")],
    ...(users[id].role === "admin" ? [[Markup.button.callback("🛠️ Admin Panel", "admin_panel")]] : [])
  ]));
});

async function buatAkun(ctx, jenis, mintaPassword, genLink) {
  const id = ctx.from.id;
  const users = load(FILES.users);
  const servers = load(FILES.servers);
  const serverName = Object.keys(servers)[0];
  const domain = servers[serverName];

  const username = await inputStep(ctx, `Masukkan username untuk ${jenis.toUpperCase()}:`);
  const password = mintaPassword ? await inputStep(ctx, `Masukkan password:`) : uuidv4().slice(0, 8);
  const days = parseInt(await inputStep(ctx, `Masukkan masa aktif (1–60 hari):`));

  const prices = load(FILES.prices);
  const total = prices[jenis] * days;
  if (isNaN(days) || days < 1 || days > 60) return ctx.reply("❌ Masa aktif tidak valid.");
  if (users[id].saldo < total) return ctx.reply("❌ Saldo tidak cukup.");

  users[id].saldo -= total;
  save(FILES.users, users);

  const uuid = uuidv4();
  const link = genLink(username, password, uuid, domain);

  ctx.reply(`✅ Akun ${jenis.toUpperCase()} berhasil dibuat\nServer: ${serverName}\nUsername: ${username}\nHari: ${days}\nHarga: Rp${total}\nLink: ${link}`);
}

// Callback handlers
bot.action("create_ssh", (ctx) => buatAkun(ctx, "ssh", true, (u, p, _, d) => `ssh://${u}:${p}@${d}:22`));
bot.action("create_vmess", (ctx) => buatAkun(ctx, "vmess", false, (u, _, uuid, d) => `vmess://${Buffer.from(JSON.stringify({ v: "2", ps: u, add: d, port: "443", id: uuid, aid: "0", net: "ws", type: "none", host: d, path: "/vmess", tls: "tls" })).toString("base64")}`));
bot.action("create_vless", (ctx) => buatAkun(ctx, "vless", false, (u, _, uuid, d) => `vless://${uuid}@${d}:443?encryption=none&security=tls&type=ws&host=${d}&path=/vless#${u}`));
bot.action("create_trojan", (ctx) => buatAkun(ctx, "trojan", false, (u, _, uuid, d) => `trojan://${uuid}@${d}:443?security=tls&type=ws&host=${d}&path=/trojan#${u}`));

bot.action("admin_panel", async (ctx) => {
  await ctx.editMessageText("🛠️ Admin Panel:", Markup.inlineKeyboard([
    [Markup.button.callback("➕ Tambah Server VPN", "add_server"), Markup.button.callback("💳 Tambah Saldo", "tambah_saldo")],
    [Markup.button.callback("➖ Kurangi Saldo", "kurangi_saldo"), Markup.button.callback("🔁 Ubah Role", "ubah_role")],
    [Markup.button.callback("💰 Atur Harga", "atur_harga"), Markup.button.callback("📢 Broadcast", "broadcast")],
    [Markup.button.callback("⬅️ Kembali", "back_to_main")]
  ]));
});

bot.action("back_to_main", (ctx) => ctx.reply("⬅️ Kembali ke menu utama. Ketik /start untuk kembali."));

bot.launch();
