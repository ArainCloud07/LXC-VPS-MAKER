#!/bin/bash
# ==========================================================
# Arain Cloud - LXC VPS Creator + SSH/Port Forward
# MOTD EXACT SAME AS PROVIDED
# Powered by Arain Cloud ☁️
# ==========================================================

# Root check
if [[ $EUID -ne 0 ]]; then
  echo "❌ Run as root"
  exit 1
fi

HOST_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

clear
echo "☁️ Arain Cloud VPS Deployment"
echo "----------------------------------"

# ===============================
# VPS INPUTS
# ===============================
read -p "📦 Container Name: " CONTAINER
read -p "💾 RAM (GB): " RAM
read -p "🧠 CPU Cores: " CPU
read -p "📀 Disk Size (GB): " DISK

# ===============================
# OS SELECTION
# ===============================
echo ""
echo "🖥 Select OS"
echo "1) Ubuntu 20.04"
echo "2) Ubuntu 22.04"
echo "3) Ubuntu 24.04"
echo "4) Debian 10"
echo "5) Debian 11"
echo "6) Debian 12"
echo "7) Debian 13"
read -p "➡ Choose [1-7]: " OS_CHOICE

case $OS_CHOICE in
  1) OS="ubuntu:20.04" ;;
  2) OS="ubuntu:22.04" ;;
  3) OS="ubuntu:24.04" ;;
  4) OS="images:debian/10" ;;
  5) OS="images:debian/11" ;;
  6) OS="images:debian/12" ;;
  7) OS="images:debian/13" ;;
  *) echo "❌ Invalid OS"; exit 1 ;;
esac

RAM_MB=$((RAM * 1024))

# ===============================
# CREATE CONTAINER
# ===============================
lxc init "$OS" "$CONTAINER" || exit 1
lxc config set "$CONTAINER" limits.memory ${RAM_MB}MB
lxc config set "$CONTAINER" limits.cpu "$CPU"
lxc config device set "$CONTAINER" root size=${DISK}GB
lxc config set "$CONTAINER" security.nesting true
lxc config set "$CONTAINER" security.privileged true

lxc start "$CONTAINER"
sleep 8

# ===============================
# ROOT PASSWORD (AUTO)
# ===============================
ROOT_PASS=$(tr -dc 'A-Za-z0-9@#%_' </dev/urandom | head -c 14)

lxc exec "$CONTAINER" -- bash -c "
echo root:$ROOT_PASS | chpasswd
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y sudo curl openssh-server >/dev/null 2>&1 || true
"

# ===============================
# SSH CONFIG
# ===============================
lxc exec "$CONTAINER" -- bash -c '
cat <<EOF > /etc/ssh/sshd_config
PasswordAuthentication yes
PermitRootLogin yes
PubkeyAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
AllowTcpForwarding yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
systemctl restart ssh || service ssh restart
'

# ===============================
# MOTD (100% SAME AS YOUR FILE)
# ===============================
lxc exec "$CONTAINER" -- bash -c '
chmod -x /etc/update-motd.d/* 2>/dev/null

cat << "EOF" > /etc/update-motd.d/00-arainnodes
#!/bin/bash

CYAN="\e[38;5;45m"
GREEN="\e[38;5;82m"
YELLOW="\e[38;5;220m"
BLUE="\e[38;5;51m"
RESET="\e[0m"

LOAD=$(uptime | awk -F "load average:" "{ print \$2 }" | awk "{ print \$1 }")
MEM_TOTAL=$(free -m | awk "/Mem:/ {print \$2}")
MEM_USED=$(free -m | awk "/Mem:/ {print \$3}")
MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))
DISK_USED=$(df -h / | awk "NR==2 {print \$3}")
DISK_TOTAL=$(df -h / | awk "NR==2 {print \$2}")
DISK_PERC=$(df -h / | awk "NR==2 {print \$5}")
PROC=$(ps aux | wc -l)
USERS=$(who | wc -l)
IP=$(hostname -I | awk "{print \$1}")
UPTIME=$(uptime -p | sed "s/up //")

echo -e "${GREEN} Welcome to Arain Cloud Datacenter 🚀 ${RESET}\n"
printf "CPU Load     : %s\n" "$LOAD"
printf "Memory Usage : %sMB / %sMB (%s%%)\n" "$MEM_USED" "$MEM_TOTAL" "$MEM_PERC"
printf "Disk Usage   : %s / %s (%s)\n" "$DISK_USED" "$DISK_TOTAL" "$DISK_PERC"
printf "Processes    : %s\n" "$PROC"
printf "Users Logged : %s\n" "$USERS"
printf "IP Address   : %s\n" "$IP"
printf "Uptime       : %s\n" "$UPTIME"
EOF

chmod +x /etc/update-motd.d/00-arainnodes
'

# ===============================
# PORT FORWARD OPTION
# ===============================
read -p "🔌 Do you want to automatically configure SSH port forwarding? (y/n): " PORT_CHOICE

if [[ "$PORT_CHOICE" =~ ^[Yy]$ ]]; then
    # Automatic SSH port forward
    VPS_PORT=22
    # Find a free host port (20000-50000)
    while : ; do
        HOST_PORT=$((RANDOM%30000+20000))
        ss -ltn | grep -q ":$HOST_PORT" || break
    done
else
    # Manual port forwarding
    read -p "🔌 VPS Internal Port: " VPS_PORT
    read -p "🌍 Host Public Port: " HOST_PORT
fi

# Add LXC proxy device
lxc config device add "$CONTAINER" tcp_$HOST_PORT proxy \
listen=tcp:0.0.0.0:$HOST_PORT connect=tcp:127.0.0.1:$VPS_PORT

lxc config device add "$CONTAINER" udp_$HOST_PORT proxy \
listen=udp:0.0.0.0:$HOST_PORT connect=udp:127.0.0.1:$VPS_PORT

# ===============================
# FINAL OUTPUT
# ===============================
clear
echo "☁️ Arain Cloud VPS READY"
echo "----------------------------------"
echo "📦 Container : $CONTAINER"
echo "🖥 OS        : $OS"
echo "💾 RAM       : ${RAM}GB"
echo "🧠 CPU       : $CPU"
echo "📀 Disk      : ${DISK}GB"
echo ""
echo "🌐 HOST IP   : $HOST_IP"
echo "🔌 SSH PORT  : $HOST_PORT"
echo ""
echo "🔑 ROOT LOGIN"
echo "User     : root"
echo "Password : $ROOT_PASS"
echo ""
echo "📡 SSH COMMAND"
echo "ssh root@$HOST_IP -p $HOST_PORT"
echo ""
echo "☁️ Powered by Arain Cloud"
