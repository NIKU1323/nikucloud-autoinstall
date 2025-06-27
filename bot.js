const { Telegraf, Markup } = require("telegraf");
const fs = require("fs");
const path = require("path");
const axios = require("axios");
const { v4: uuidv4 } = require("uuid");

const bot = new Telegraf("7841665275:AAEcSrfMKMIOCSX7kHAXo88C2R-A2g3ehWU"); // Ganti dengan token asli
const ADMIN_ID = 7775876956; // Ganti dengan ID admin Telegram
const dataDir = path.join(__dirname, "data");
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir);

const FILES = {
  users: path.join(dataDir, "users.json"),
  prices: path.join(dataDir, "prices.json"),
  servers: path.join(dataDir, "servers.json"),
  allowed: path.join(dataDir, "allowed.json")
};

// Helper functions
const load = (file) => fs.existsSync(file) ? JSON.parse(fs.readFileSync(file)) : {};
const save = (file, data) => fs.writeFileSync(file, JSON.stringify(data, null, 2));

// Initialize files if not exists
if (!fs.existsSync(FILES.users)) save(FILES.users, {});
if (!fs.existsSync(FILES.prices)) save(FILES.prices, {
  ssh: 334,
  vmess: 334,
  vless: 334,
  trojan: 334,
  reg_ip: 2000,
  buyvps: 30000
});
if (!fs.existsSync(FILES.servers)) save(FILES.servers, { "Server 1": "example.com" });
if (!fs.existsSync(FILES.allowed)) save(FILES.allowed, []);

// VPS Command Function
async function sendCommandToVPS(ip, authCode, command) {
  try {
    const res = await axios.post(`http://${ip}:6969/exec`, {
      auth_code: authCode,
      command: command
    }, { timeout: 5000 });
    return res.data.output || "✅ Perintah berhasil dikirim.";
  } catch (err) {
    return `[❌] Gagal terhubung ke VPS: ${err.message}`;
  }
}

// Slot Management
function tambahSlot(ctx) {
  const allowed = load(FILES.allowed);
  ctx.reply("Masukkan auth_code yang ingin ditambah slot VPS-nya:");
  
  const textListener = (msg1) => {
    bot.off('text', textListener); // Remove listener after first use
    const code = msg1.text.trim();
    const data = allowed.find(a => a.auth_code === code);
    
    if (!data) return ctx.reply("❌ Auth code tidak ditemukan.");
    
    ctx.reply("Masukkan jumlah tambahan slot VPS:");
    
    const numberListener = (msg2) => {
      bot.off('text', numberListener); // Remove listener after first use
      const tambah = parseInt(msg2.text);
      
      if (isNaN(tambah) || tambah < 1) return ctx.reply("❌ Jumlah tidak valid.");
      
      data.max_vps += tambah;
      save(FILES.allowed, allowed);
      ctx.reply(`✅ Berhasil menambah ${tambah} slot ke auth_code ${code}\nTotal slot VPS sekarang: ${data.max_vps}`);
    };
    
    bot.on('text', numberListener);
  };
  
  bot.on('text', textListener);
}

// Account Creation
async function buatAkun(ctx, jenis, mintaPassword, genLink) {
  const id = ctx.from.id;
  const users = load(FILES.users);
  const servers = load(FILES.servers);
  const allowed = load(FILES.allowed);
  const serverName = Object.keys(servers)[0];
  const domain = servers[serverName];

  const vpsAuth = allowed.find(s => s.hostname === serverName || s.ip === domain);
  if (!vpsAuth) return ctx.reply("❌ Server belum terdaftar atau belum ada auth_code.");

  ctx.reply(`Masukkan username untuk ${jenis.toUpperCase()}:`);
  
  const usernameListener = (msg1) => {
    bot.off('text', usernameListener);
    const user = msg1.text.trim();
    
    const processAccount = async (password = "") => {
      ctx.reply("Masukkan masa aktif (1-60 hari):");
      
      const daysListener = async (msg2) => {
        bot.off('text', daysListener);
        const days = parseInt(msg2.text);
        const prices = load(FILES.prices);
        const total = prices[jenis] * days;

        if (isNaN(days) || days < 1 || days > 60) return ctx.reply("❌ Masa aktif tidak valid.");
        if (users[id].saldo < total) return ctx.reply("❌ Saldo tidak cukup.");

        users[id].saldo -= total;
        save(FILES.users, users);

        const uuid = uuidv4();
        const link = genLink(user, password, uuid, domain);

        const command = `bash add-${jenis}.sh ${user} ${password || uuid} ${days}`;
        const hasil = await sendCommandToVPS(vpsAuth.ip, vpsAuth.auth_code, command);

        ctx.reply(`✅ Akun ${jenis.toUpperCase()} berhasil dibuat\nServer: ${serverName}\nUsername: ${user}\nHari: ${days}\nHarga: Rp${total}\nLink: ${link}\n\nRespon VPS:\n${hasil}`);
      };
      
      bot.on('text', daysListener);
    };

    if (mintaPassword) {
      ctx.reply("Masukkan password:");
      const passwordListener = (msg3) => {
        bot.off('text', passwordListener);
        processAccount(msg3.text.trim());
      };
      bot.on('text', passwordListener);
    } else {
      processAccount();
    }
  };
  
  bot.on('text', usernameListener);
}

// Start Command
bot.start((ctx) => {
  const id = ctx.from.id;
  const users = load(FILES.users);
  if (!users[id]) users[id] = { saldo: 0, role: "user" };
  save(FILES.users, users);

  const uptime = process.uptime();
  const h = Math.floor(uptime / 3600);
  const m = Math.floor((uptime % 3600) / 60);
  const s = Math.floor(uptime % 60);
  const userCount = Object.keys(users).length;

  ctx.replyWithMarkdown(`🛒 *MERCURY VPN — Bot E-Commerce VPN & Digital*
━━━━━━━━━━━━━━━━━━━━━━
📈 *Statistik Toko:*
• 👥 Pengguna: ${userCount}
• ⏱️ Uptime Bot: ${h}j ${m}m ${s}d
━━━━━━━━━━━━━━━━━━━━━━
👤 *Akun Anda:*
• 🆔 ID: ${id}
• Username: @${ctx.from.username || "-"}
• Role: ${users[id].role}
• Saldo: Rp${users[id].saldo}
━━━━━━━━━━━━━━━━━━━━━━
Customer Service: @mercurystore12
━━━━━━━━━━━━━━━━━━━━━━`, {
    reply_markup: {
      inline_keyboard: [
        [
          { text: "🔐 SSH", callback_data: "create_ssh" },
          { text: "🌀 VMESS", callback_data: "create_vmess" }
        ],
        [
          { text: "📡 VLESS", callback_data: "create_vless" },
          { text: "⚡ TROJAN", callback_data: "create_trojan" }
        ],
        [{ text: "🖥️ Registrasi IP VPS", callback_data: "reg_ip" }],
        [{ text: "💳 Topup Saldo", callback_data: "topup" }],
        [{ text: "🧾 List Akun VPN", callback_data: "list_vpn" }],
        [{ text: "❌ Hapus Akun VPN", callback_data: "hapus_vpn" }],
        [{ text: "💻 Beli VPS", callback_data: "buy_vps" }],
        ...(users[id].role === "admin" ? [[{ text: "🛠️ Admin Panel", callback_data: "admin_panel" }]] : [])
      ]
    }
  });
});

// Action Handlers
bot.action("create_ssh", (ctx) => buatAkun(ctx, "ssh", true, (u, p, _, d) => `ssh://${u}:${p}@${d}:22`));
bot.action("create_vmess", (ctx) => buatAkun(ctx, "vmess", false, (u, _, uuid, d) => `vmess://${Buffer.from(JSON.stringify({ 
  v: "2", ps: u, add: d, port: "443", id: uuid, aid: "0", net: "ws", type: "none", host: d, path: "/vmess", tls: "tls" 
})).toString("base64")}`));
bot.action("create_vless", (ctx) => buatAkun(ctx, "vless", false, (u, _, uuid, d) => `vless://${uuid}@${d}:443?encryption=none&security=tls&type=ws&host=${d}&path=/vless#${u}`));
bot.action("create_trojan", (ctx) => buatAkun(ctx, "trojan", false, (u, _, uuid, d) => `trojan://${uuid}@${d}:443?security=tls&type=ws&host=${d}&path=/trojan#${u}`));

bot.action("admin_panel", (ctx) => {
  ctx.editMessageText("🛠️ Admin Panel:", {
    reply_markup: {
      inline_keyboard: [
        [
          { text: "➕ Tambah Server VPN", callback_data: "add_server" }, 
          { text: "💳 Tambah Saldo", callback_data: "tambah_saldo" }
        ],
        [
          { text: "➖ Kurangi Saldo", callback_data: "kurangi_saldo" }, 
          { text: "🔁 Ubah Role", callback_data: "ubah_role" }
        ],
        [
          { text: "🔓 Tambah Slot VPS", callback_data: "tambah_slot" }, 
          { text: "💰 Atur Harga", callback_data: "atur_harga" }
        ],
        [{ text: "📢 Broadcast", callback_data: "broadcast" }],
        [{ text: "⬅️ Kembali", callback_data: "back_to_main" }]
      ]
    }
  });
});

bot.action("tambah_slot", (ctx) => tambahSlot(ctx));
bot.action("back_to_main", (ctx) => ctx.deleteMessage());

// IP Registration
bot.action("reg_ip", (ctx) => {
  const users = load(FILES.users);
  const id = ctx.from.id;

  if (!users[id]) return ctx.reply("❌ Akun Anda belum terdaftar.");

  ctx.reply("📡 Masukkan IP VPS yang ingin diregistrasi:");
  
  const ipListener = (msg1) => {
    bot.off('text', ipListener);
    const ip = msg1.text.trim();
    
    ctx.reply("🔐 Masukkan nama hostname VPS (cth: vps-singapore):");
    
    const hostnameListener = (msg2) => {
      bot.off('text', hostnameListener);
      const hostname = msg2.text.trim();
      
      ctx.reply("🕒 Masukkan masa aktif VPS (dalam hari):");
      
      const daysListener = (msg3) => {
        bot.off('text', daysListener);
        const hari = parseInt(msg3.text);
        const prices = load(FILES.prices);
        const total = prices.reg_ip;

        if (isNaN(hari) || hari < 1 || hari > 90) return ctx.reply("❌ Masa aktif tidak valid.");
        if (users[id].saldo < total) return ctx.reply("❌ Saldo tidak cukup.");

        users[id].saldo -= total;
        save(FILES.users, users);

        const allowed = load(FILES.allowed);
        const auth_code = `AUTH-${uuidv4().split('-')[0]}`;
        const expired = new Date(Date.now() + hari * 86400000).toISOString();

        allowed.push({
          ip: ip,
          hostname: hostname,
          auth_code: auth_code,
          expired: expired,
          user_id: id,
          max_vps: 1
        });

        save(FILES.allowed, allowed);

        ctx.reply(`✅ VPS berhasil diregistrasi\n\n🖥️ Hostname: ${hostname}\n🌐 IP: ${ip}\n🔐 Auth Code: ${auth_code}\n🕒 Aktif s.d: ${expired.split('T')[0]}\n💰 Harga: Rp${total}`);
      };
      
      bot.on('text', daysListener);
    };
    
    bot.on('text', hostnameListener);
  };
  
  bot.on('text', ipListener);
});

// Error Handling
bot.catch((err, ctx) => {
  console.error(`Error for ${ctx.updateType}:`, err);
  ctx.reply("❌ Terjadi kesalahan saat memproses permintaan Anda.");
});

// Start Bot
bot.launch()
  .then(() => console.log('Bot started successfully'))
  .catch(err => console.error('Bot failed to start:', err));

// Graceful Shutdown
process.once('SIGINT', () => {
  bot.stop('SIGINT');
  process.exit();
});

process.once('SIGTERM', () => {
  bot.stop('SIGTERM');
  process.exit();
});
