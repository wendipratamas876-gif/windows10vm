FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

RUN apt-get update && apt-get install -y \
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

# noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# ✅ WINDOWS OFFICIAL (STABLE)
ENV ISO_URL="https://software.download.prss.microsoft.com/dbazure/Win10_22H2_English_x64.iso"

RUN cat <<'EOF' > /start.sh
#!/bin/bash

echo "🚀 Starting Windows VM (SAFE MODE)"

# download iso (never exit)
if [ ! -f /iso/os.iso ]; then
  echo "📥 Downloading Windows ISO..."
  wget --tries=10 --timeout=30 --continue "$ISO_URL" -O /iso/os.iso || true
fi

# create disk
if [ ! -f /data/disk.qcow2 ]; then
  qemu-img create -f qcow2 /data/disk.qcow2 60G
fi

# start vm
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

echo "=================================="
echo "VNC : http://<IP>:6080"
echo "RDP : <IP>:3389"
echo "=================================="

tail -f /dev/null
EOF

RUN chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 3389
CMD ["/start.sh"]
