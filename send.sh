#!/bin/bash

# === Konfigurasi ===
ANYKERNEL_DIR="AnyKernel3"
OUTPUT_ZIP="Kernel-$(date +%Y%m%d-%H%M).zip"
BOT_TOKEN="-"
CHAT_ID="-"  # Misal: 123456789 atau @namachannel

# Lokasi hasil build kernel, sesuaikan dengan folder build kamu
KERNEL_BUILD_DIR="out/arch/arm64/boot"
IMAGE_DTB="Image.gz-dtb"

# === Pengecekan awal ===
if [ ! -d "$ANYKERNEL_DIR" ]; then
    echo "[!] Folder $ANYKERNEL_DIR tidak ditemukan!"
    exit 1
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[!] BOT_TOKEN atau CHAT_ID belum diisi!"
    exit 1
fi

# Pastikan file Image.gz-dtb ada
if [ ! -f "$KERNEL_BUILD_DIR/$IMAGE_DTB" ]; then
    echo "[!] File $IMAGE_DTB tidak ditemukan di $KERNEL_BUILD_DIR!"
    exit 1
fi

# Copy Image.gz-dtb ke AnyKernel3
cp "$KERNEL_BUILD_DIR/$IMAGE_DTB" "$ANYKERNEL_DIR/"

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
