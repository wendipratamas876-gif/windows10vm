FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    curl \
    unzip \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

# Install noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

# Create start script (CORRECT WAY)
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

echo "🚀 Starting Windows VM"

# Download ISO
if [ ! -f /iso/os.iso ]; then
  echo "📥 Downloading Windows ISO..."
  wget --progress=dot:giga "$ISO_URL" -O /iso/os.iso
fi

# Create disk
if [ ! -f /data/disk.qcow2 ]; then
  echo "💽 Creating disk..."
  qemu-img create -f qcow2 /data/disk.qcow2 60G
fi

# Boot logic
BOOT_ORDER="-boot order=c"
if [ ! -f /data/.installed ]; then
  echo "🆕 First boot (Windows installer)"
  BOOT_ORDER="-boot order=d"
fi

# Start QEMU (SAFE FOR ZEABUR)
qemu-system-x86_64 \
  -machine pc \
  -cpu qemu64 \
  -m 2048 \
  -smp 2 \
  -vga std \
  -usb -device usb-tablet \
  $BOOT_ORDER \
  -drive file=/data/disk.qcow2,format=qcow2 \
  -cdrom /iso/os.iso \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  -display vnc=:0 &

# Start noVNC
sleep 5
websockify --web /novnc 6080 localhost:5900 &

echo "===================================================="
echo "🌐 noVNC  : http://localhost:6080"
echo "🔌 RDP    : localhost:3389"
echo "⏳ First boot bisa 20-30 menit"
echo "===================================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 3389
CMD ["/start.sh"]
