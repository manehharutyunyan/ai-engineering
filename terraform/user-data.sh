#!/bin/bash
set -euo pipefail

dnf install -y docker rsync git
systemctl enable --now docker
usermod -aG docker ec2-user

# docker compose v2 CLI plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

mkdir -p /home/ec2-user/resolve
chown -R ec2-user:ec2-user /home/ec2-user/resolve

# optional extra login user (var.extra_ssh_user)
EXTRA_USER="${extra_user}"
if [ -n "$EXTRA_USER" ]; then
  id "$EXTRA_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$EXTRA_USER"
  usermod -aG docker "$EXTRA_USER"
  install -d -m 700 -o "$EXTRA_USER" -g "$EXTRA_USER" "/home/$EXTRA_USER/.ssh"
  echo "${extra_key}" > "/home/$EXTRA_USER/.ssh/authorized_keys"
  chown "$EXTRA_USER:$EXTRA_USER" "/home/$EXTRA_USER/.ssh/authorized_keys"
  chmod 600 "/home/$EXTRA_USER/.ssh/authorized_keys"
fi
