FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    unzip \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

# Install noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ISO (Lite, paling aman)
ENV ISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%2010%20Lite%20Edition%2019H2%20x64.iso"

RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

echo "🚀 Starting Windows VM (ANTI BSOD MODE)"

# download ISO (jangan crash kalau gagal)
if [ ! -f /iso/os.iso ]; then
  echo "📥 Downloading Windows ISO..."
  wget --timeout=30 --tries=3 "$ISO_URL" -O /iso/os.iso || echo "⚠️ ISO download skipped"
fi

# disk
if [ ! -f /data/disk.qcow2 ]; then
  echo "💽 Creating disk..."
  qemu-img create -f qcow2 /data/disk.qcow2 40G
fi

# boot logic
BOOT="-boot order=c"
if [ ! -f /data/.installed ]; then
  BOOT="-boot order=d"
  echo "🆕 Installer mode"
fi

# START QEMU (PALING STABIL)
qemu-system-x86_64 \
  -machine pc \
  -cpu qemu64 \
  -m 1024 \
  -smp 1 \
  -vga cirrus \
  -usb -device usb-tablet \
  -no-acpi \
  -no-hpet \
  $BOOT \
  -drive file=/data/disk.qcow2,format=qcow2,cache=writeback \
  -cdrom /iso/os.iso \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device rtl8139,netdev=net0 \
  -display vnc=:0 &

sleep 5

websockify --web /novnc 6080 localhost:5900 &

echo "===================================================="
echo "🌐 VNC  : http://IP:6080/vnc.html"
echo "🔌 RDP  : IP:3389 (setelah Windows selesai install)"
echo "⚠️  Lambat tapi STABIL (no BSOD)"
echo "===================================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 3389
CMD ["/start.sh"]
