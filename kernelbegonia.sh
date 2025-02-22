#!/bin/bash

# ⚙️ Konfigurasi Awal
KERNEL_DIR=$(pwd)
OUT_DIR=$KERNEL_DIR/out
ANYKERNEL_DIR=$KERNEL_DIR/AnyKernel3
CONFIG_NAME=begonia_user_defconfig
THREADS=$(nproc --all)
CLANGDIR="/home/vq6oon/clang"
DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$CONFIG_NAME"
DEVICE_CODENAME="begonia"
USER="vq6oon"
HOSTNAME="Lamp1onProject"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ✨ Biar Keren
clear; screenfetch

# 📡 Telegram
BOT_TOKEN="8119463254:AAFzOFyjTWKAYDIGMqEZ_i8eZyNEEvvNu00"
CHAT_ID="-1002688012617_5"
MESSAGE_THREAD_ID="4"

# 📩 Fungsi kirim pesan ke Telegram
send_telegram_message() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "message_thread_id=$MESSAGE_THREAD_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown"
}

# 📂 Fungsi kirim file ke Telegram
send_telegram_file() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F "chat_id=$CHAT_ID" \
        -F "message_thread_id=$MESSAGE_THREAD_ID" \
        -F "document=@$1" \
        -F "caption=$2" \
        -F "parse_mode=Markdown"
}

# 🧹 Hapus AnyKernel3 lama
echo "🗑️ Menghapus AnyKernel3 yang lama..."
rm -rf AnyKernel3

# 🔖 Ambil LOCALVERSION (Set Manual aja)
RAW_LOCALVERSION=$(grep -oP 'CONFIG_LOCALVERSION="\K[^"]+' "$DEFCONFIG_FILE")
KERNEL_NAME=$(echo "$RAW_LOCALVERSION" | sed 's/^-//')
[ -z "$KERNEL_NAME" ] && KERNEL_NAME="CustomKernel"

# 📥 Clone AnyKernel3 jika belum ada
if [ ! -d "$ANYKERNEL_DIR" ]; then
#    cp -r /home/vq6oon/AnyKernel3/AnyKernel3 "$ANYKERNEL_DIR"
    git clone https://github.com/vq6oon/AnyKernel3 -b begonia "$ANYKERNEL_DIR"
fi

# 🧹 Bersihkan output lama
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# 🌍 Export build env
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOSTNAME"
export USE_CCACHE=1
ccache -M 10G
export PATH="$CLANGDIR/bin:$PATH"

# ℹ️ Info Awal
COMPILER_VERSION=$("$CLANGDIR/bin/clang" --version | head -n1)
CORES=$(nproc)
TANGGAL=$(date +"%d-%m-%Y %H:%M")

send_telegram_message "🚀 *Build Kernel Dimulai!*
━━━━━━━━━━━━━━━
🧩 Kernel: \`$KERNEL_NAME\`
💻 Host: \`$HOSTNAME\`
⚙️ Config: \`$CONFIG_NAME\`
🌿 Branch: \`$BRANCH\`
🧵 CPU: ${CORES} Cores
📅 Tanggal: $TANGGAL
🛠️ Clang: \`$COMPILER_VERSION\`
━━━━━━━━━━━━━━━"

# ⏱️ Waktu mulai
BUILD_START=$(date +%s)

# 🔨 Build & log
make O=out ARCH=arm64 $CONFIG_NAME
make -j"$THREADS" O=out LLVM=1 LLVM_IAS=1 \
  ARCH=arm64 \
  CC=clang \
  LD=ld.lld \
  AR=llvm-ar \
  AS=llvm-as \
  NM=llvm-nm \
  STRIP=llvm-strip \
  OBJCOPY=llvm-objcopy \
  OBJDUMP=llvm-objdump \
  READELF=llvm-readelf \
  HOSTCC=clang \
  HOSTCXX=clang++ \
  HOSTAR=llvm-ar \
  HOSTLD=ld.lld \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- | tee -a out/compile.log

# ⏱️ Waktu selesai
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
TANGGAL_END=$(date +"%d-%m-%Y %H:%M")

# 📦 Cek file hasil
KERNEL_IMAGE=$(find $OUT_DIR -name "Image.gz-dtb" | head -n1)

if [ -f "$KERNEL_IMAGE" ]; then
    cp "$KERNEL_IMAGE" "$ANYKERNEL_DIR/Image.gz-dtb"
    cd "$ANYKERNEL_DIR" || exit 1
    ZIP_NAME="Kurap1kaKernel-$DEVICE_CODENAME-$(date +%Y%m%d-%H%M).zip"
    zip -r9 "$ZIP_NAME" * > /dev/null 2>&1

    if [ -f "$ZIP_NAME" ]; then
        ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)

        CAPTION="✅ *Build Berhasil!* 🎉
━━━━━━━━━━━━━━━
🧩 Kernel: \`$KERNEL_NAME\`
🌿 Branch: \`$BRANCH\`
📦 Size: $ZIP_SIZE
⚡ Waktu: ${BUILD_DURATION} detik
📅 Tanggal: $TANGGAL_END
━━━━━━━━━━━━━━━"

        send_telegram_file "$ZIP_NAME" "$CAPTION"
    else
        send_telegram_message "❌ *Gagal membuat ZIP!* 💥"
    fi
else
    send_telegram_message "❌ *Build Gagal!* 💥
━━━━━━━━━━━━━━━
🧩 Kernel: \`$KERNEL_NAME\`
🌿 Branch: \`$BRANCH\`
⚡ Waktu: ${BUILD_DURATION} detik
📅 Tanggal: $TANGGAL_END
━━━━━━━━━━━━━━━"
    send_telegram_file "$KERNEL_DIR/out/compile.log" "⚠️ *Log Build Gagal*"
fi
