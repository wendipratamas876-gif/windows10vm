# Windows 10 Lite on QEMU + noVNC + ngrok (Railway-safe, no VOLUME)
FROM ubuntu:22.04

ARG NGROK_TOKEN
ARG REGION=ap

ENV DEBIAN_FRONTEND=noninteractive \
    NGROK_TOKEN=$NGROK_TOKEN \
    REGION=$REGION

# 1. base + QEMU + noVNC + ngrok
RUN apt-get update && apt-get install -y --no-install-recommends \
      qemu-system-x86 qemu-utils novnc websockify wget curl net-tools unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. noVNC latest
RUN wget -q https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && mv /tmp/noVNC-master /novnc && rm /tmp/novnc.zip

# 3. ngrok binary
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok.zip && \
    cd / && unzip ngrok.zip && rm ngrok.zip && chmod +x ngrok

# 4. start script (QEMU + tunnel 3389 & 6080)
RUN printf '#!/bin/bash\n\
mkdir -p /data /iso\n\
# tunnel RDP + VNC\n/ngrok tcp --authtoken "${NGROK_TOKEN}" --region "${REGION}" 3389 &\n/ngrok tcp --authtoken "${NGROK_TOKEN}" --region "${REGION}" 6080 &\n\
# disk 80 GB\n[ ! -f /data/disk.qcow2 ] && qemu-img create -f qcow2 /data/disk.qcow2 80G\n\
# ISO Windows 10 Lite\nISO_URL="https://archive.org/download/windows-10-lite-edition-19h2-x64/Windows%%2010%%20Lite%%20Edition%%2019H2%%20x64.iso"\n[ ! -f /iso/os.iso ] && wget -q --show-progress "$ISO_URL" -O /iso/os.iso\n\
# QEMU (no KVM, TCG only)\nqemu-system-x86_64 \\\n  -machine q35,accel=tcg \\\n  -cpu qemu64 \\\n  -m 2G -smp 2 \\\n  -boot order=d,menu=on \\\n  -drive file=/data/disk.qcow2,format=qcow2 \\\n  -drive file=/iso/os.iso,media=cdrom \\\n  -netdev user,id=net0,hostfwd=tcp::3389-:3389 \\\n  -device e1000,netdev=net0 \\\n  -display vnc=:0 -vga std -usb -device usb-tablet &\n\
# noVNC\nsleep 5\nwebsockify --web /novnc 6080 localhost:5900 &\n\
echo "======================================"\necho "VNC : http://<ngrok-host>:<ngrok-port>/vnc.html"\necho "RDP : <ngrok-host>:<ngrok-port-3389>"\necho "Username: Administrator (atau root/kelvin123 via SSH)"\necho "Password: (kosongkan saat first boot, buat sendiri nanti)"\necho "======================================"\ntail -f /dev/null\n' > /start.sh && chmod +x /start.sh

EXPOSE 6080 3389
CMD ["/start.sh"]
