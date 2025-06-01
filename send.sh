#!/bin/bash

# === Konfigurasi ===
ANYKERNEL_DIR="kernwl"
OUTPUT_ZIP="Kernel-$(date +%Y%m%d-%H%M).zip"
BOT_TOKEN="isi_token_bot_kamu"
CHAT_ID="isi_chat_id_atau_channel_id_kamu"  # Misal: 123456789 atau @namachannel

# === Pengecekan awal ===
if [ ! -d "$ANYKERNEL_DIR" ]; then
    echo "[!] Folder $ANYKERNEL_DIR tidak ditemukan!"
    exit 1
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[!] BOT_TOKEN atau CHAT_ID belum diisi!"
    exit 1
fi

# === Packing ZIP ===
echo "[*] Mem-packing AnyKernel3 ke ZIP..."
cd "$ANYKERNEL_DIR" || exit
zip -r9 "../$OUTPUT_ZIP" ./* > /dev/null
cd ..

echo "[+] ZIP berhasil dibuat: $OUTPUT_ZIP"

# === Mengirim ke Telegram ===
echo "[*] Mengirim ZIP ke Telegram..."

curl -F document=@"$OUTPUT_ZIP" \
     -F chat_id="$CHAT_ID" \
     -F caption="📦 Build Kernel Baru\n🧾 File: $OUTPUT_ZIP" \
     "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"

echo "[+] File berhasil dikirim ke Telegram."
