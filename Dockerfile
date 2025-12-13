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
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ✅ Tiny10 (STABLE)
ENV ISO_URL="https://files.catbox.moe/7g9b5x.iso"

RUN cat <<'EOF' > /start.sh
#!/bin/bash
set +e

echo "🚀 Starting Tiny10 VM"

if [ ! -f /iso/os.iso ]; then
  echo "📥 Downloading Tiny10 ISO..."
  wget --tries=5 --timeout=30 --continue "$ISO_URL" -O /iso/os.iso || tail -f /dev/null
fi

if [ ! -f /data/disk.qcow2 ]; then
  qemu-img create -f qcow2 /data/disk.qcow2 60G
fi

qemu-system-x86_64 \
  -machine pc \
  -cpu qemu64 \
  -m 2048 \
  -smp 2 \
  -vga cirrus \
  -usb -device usb-tablet \
  -boot order=d \
  -drive file=/data/disk.qcow2,format=qcow2 \
  -cdrom /iso/os.iso \
  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \
  -device e1000,netdev=net0 \
  -display vnc=:0 &

sleep 5
websockify --web /novnc 6080 localhost:5900 &

tail -f /dev/null
EOF

RUN chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 3389
CMD ["/start.sh"]
