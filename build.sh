#!/bin/bash
# ============================================================================
#  build.sh – Unified build, KPM‑patch, AnyKernel ZIP & Telegram notifier
#  Copyright (c) zetaxbyte – t.me/@zetaxbyte
#  Merged & super‑charged by ChatGPT (2025‑06‑19)
# ---------------------------------------------------------------------------
#  ✦  Auto‑clone Proton‑Clang (if missing)
#  ✦  Build kernel with selectable DEFCONFIG/branch
#  ✦  Optionally apply SukiSU KPM patch (CONFIG_KPM=y)
#  ✦  Package flashable ZIP via AnyKernel3 (auto‑clone/branch)
#  ✦  Stream logs & artifacts to Telegram
# ============================================================================

#=============================#
#        CONFIG SECTION       #
#=============================#

# Directories
KERNEL_DIR=$(pwd)
OUT_DIR="$KERNEL_DIR/out"
KERNEL_IMAGE_DIR="$OUT_DIR/arch/arm64/boot"
KERNEL_IMAGE="$KERNEL_IMAGE_DIR/Image.gz-dtb"
LOG_FILE="$KERNEL_DIR/build.log"

# Toolchain (Proton‑Clang)
TC_DIR="$KERNEL_DIR/../proton-clang"        # auto‑cloned if missing
CLANGDIR="$TC_DIR"                          # for compatibility with old script

# Build parameters
DEFCONFIG="tissot_defconfig"                # change to your defconfig
#DEFCONFIG="tama_aurora_kddi_defconfig"    # example alt‑defconfig
export KBUILD_BUILD_USER="mhdputerapmgks"
export KBUILD_BUILD_HOST="Nebula"

# AnyKernel3 packaging
ANYKERNEL_REPO="https://github.com/mhdputerapmgks/AnyKernel3.git"
ANYKERNEL_BRANCH="master"
ANYKERNEL_DIR="$KERNEL_DIR/AnyKernel3"
KERNEL_NAME="Voyager_KSUN_Non_Treble"

# Telegram bot
BOT_TOKEN="7872159515:AAEBhUIpjSj-fc_HmhpWxFVmMwkBlb1cayE"
CHAT_ID="679947529"

#=============================#
#     TELEGRAM FUNCTIONS      #
#=============================#

escape_markdown_v2() { 
    echo "$1" | sed -e 's/\\/\\\\/g' -e 's/_/\\_/g' -e 's/\*/\\*/g' \
        -e 's/\[/\\[/g' -e 's/\]/\\]/g' -e 's/(/\\(/g' -e 's/)/\\)/g' \
        -e 's/~/\\~/g' -e 's/`/\\`/g' -e 's/>/\\>/g' -e 's/#/\\#/g' \
        -e 's/+/\\+/g' -e 's/-/\\-/g' -e 's/=/\\=/g' -e 's/|/\\|/g' \
        -e 's/{/\\{/g' -e 's/}/\\}/g';
}

send_telegram_message() {
    local MESSAGE="$(escape_markdown_v2 "$1")"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" -d "text=$MESSAGE" -d "parse_mode=MarkdownV2" >/dev/null
}

send_telegram_file() {
    local FILE_PATH="$1"
    local FILE_NAME=$(basename "$FILE_PATH")
    local CAPTION="\`$(escape_markdown_v2 "$FILE_NAME")\`"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F "chat_id=$CHAT_ID" \
        -F "document=@$FILE_PATH" \
        -F "caption=$CAPTION" \
        -F "parse_mode=MarkdownV2" >/dev/null
}

#=============================#
#         COLOR SETUP         #
#=============================#
C_RESET="\033[0m"; C_CYAN="\033[96m"; C_GREEN="\033[92m"; C_RED="\033[91m"; C_BLUE="\033[94m"; C_YELLOW="\033[93m"

#=============================#
#        STOP HANDLING        #
#=============================#
stop_handler() {
    send_telegram_message "⚠️ Compilation was unexpectedly stopped!"
    [ -f "$LOG_FILE" ] && send_telegram_file "$LOG_FILE"
    echo -e "${C_RED}[!] Build interrupted${C_RESET}"
    exit 1
}
trap stop_handler ERR INT

#=============================#
#       TOOLCHAIN CHECK       #
#=============================#
echo -e "${C_CYAN}=== Checking Proton‑Clang …${C_RESET}"
if [ ! -d "$TC_DIR" ]; then
    echo -e "${C_YELLOW}Cloning Proton‑Clang …${C_RESET}"
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git "$TC_DIR" || {
        send_telegram_message "❌ Failed to clone Proton‑Clang!"; exit 1; }
else
    echo -e "${C_GREEN}Toolchain found.${C_RESET}"
fi
export PATH="$TC_DIR/bin:$PATH"

#=============================#
#          START BUILD        #
#=============================#
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_ID=$(git rev-parse --short=7 HEAD)

send_telegram_message "🔨 Starting kernel compilation for *$DEFCONFIG* on branch *$BRANCH* …"

echo -e "${C_CYAN}===========================${C_RESET}"
echo -e "${C_CYAN}= START COMPILING KERNEL  =${C_RESET}"
echo -e "${C_CYAN}===========================${C_RESET}"

# Clean slate
rm -f "$LOG_FILE" && rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR"
make mrproper >/dev/null

# Defconfig
make O="$OUT_DIR" ARCH=arm64 "$DEFCONFIG"

# Build
make -j"$(nproc --all)" \
    O="$OUT_DIR" LLVM=1 LLVM_IAS=1 ARCH=arm64 \
    CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm STRIP=llvm-strip \
    OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf \
    HOSTCC=clang HOSTCXX=clang++ HOSTAR=llvm-ar HOSTLD=ld.lld \
    CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee "$LOG_FILE"

BUILD_RESULT=${PIPESTATUS[0]}
if [ "$BUILD_RESULT" -ne 0 ]; then
    send_telegram_message "❌ Compilation failed!"
    send_telegram_file "$LOG_FILE"
    exit 1
fi

#=============================#
#        PATCH KPM (opt)      #
#=============================#
if grep -q "^CONFIG_KPM=y" "$OUT_DIR/.config"; then
    echo -e "${C_BLUE}Applying KPM patch …${C_RESET}"
    pushd "$KERNEL_IMAGE_DIR" >/dev/null
    LATEST_PATCH_URL=$(curl -s https://api.github.com/repos/SukiSU-Ultra/SukiSU_KernelPatch_patch/releases/latest \
        | grep "browser_download_url" | grep "patch_linux" | cut -d '"' -f 4)
    curl -L -o patch_linux "$LATEST_PATCH_URL"
    chmod +x patch_linux && ./patch_linux
    rm -f Image Image.gz-dtb && mv oImage Image
    gzip -c Image > Image.gz && cat Image.gz dts/*/*.dtb > Image.gz-dtb
    popd >/dev/null
fi

#=============================#
#      CREATE FLASHABLE ZIP   #
#=============================#
if [ -f "$KERNEL_IMAGE" ]; then
    echo -e "${C_GREEN}Kernel Image found – packaging …${C_RESET}"

    # Clone AnyKernel3
    if [ ! -d "$ANYKERNEL_DIR" ]; then
        git clone "$ANYKERNEL_REPO" "$ANYKERNEL_DIR"
    fi
    pushd "$ANYKERNEL_DIR" >/dev/null
    git fetch origin && git checkout "$ANYKERNEL_BRANCH"
    popd >/dev/null

    # Copy image & build zip
    cp "$KERNEL_IMAGE" "$ANYKERNEL_DIR/Image.gz-dtb"
    pushd "$ANYKERNEL_DIR" >/dev/null
    ZIP_NAME="${KERNEL_NAME}-${COMMIT_ID}-$(date +%Y%m%d).zip"
    zip -r9 "../$ZIP_NAME" ./* >/dev/null
    popd >/dev/null

    # Send artifacts
    send_telegram_file "$KERNEL_DIR/$ZIP_NAME"
    send_telegram_file "$LOG_FILE"
    send_telegram_message "✅ Compilation completed successfully. Flashable ZIP is ready!"
else
    send_telegram_message "❌ Build succeeded, but kernel image not found!"
    send_telegram_file "$LOG_FILE"
    exit 1
fi

#=============================#
#          FINISHED           #
#=============================#
echo -e "${C_CYAN}===========================${C_RESET}"
echo -e "${C_CYAN}=   BUILD COMPLETED!     =${C_RESET}"
echo -e "${C_CYAN}===========================${C_RESET}"
