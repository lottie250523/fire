#!/bin/bash

set -e

# 配色
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RESET='\033[0m'

# 读取输入
read -p "请输入 Cloudflared Tunnel Token: " TOKEN
read -p "请输入你的 SSH 公钥（例如：ssh-rsa AAAAB3...）: " SSH_KEY

echo -e "${YELLOW}[1/5] 安装 Cloudflared...${RESET}"
if ! command -v cloudflared >/dev/null; then
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  dpkg -i cloudflared-linux-amd64.deb
  rm cloudflared-linux-amd64.deb
fi

echo -e "${YELLOW}[2/5] 禁用 ssh.socket 以避免端口冲突...${RESET}"
systemctl stop ssh.socket 2>/dev/null || true
systemctl disable ssh.socket 2>/dev/null || true
systemctl mask ssh.socket 2>/dev/null || true

echo -e "${YELLOW}[3/5] 启动 SSH 服务...${RESET}"
systemctl unmask ssh 2>/dev/null || true
systemctl enable ssh
systemctl start ssh

echo -e "${YELLOW}[4/5] 配置 SSH 公钥登录...${RESET}"
mkdir -p ~/.ssh
echo "$SSH_KEY" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

echo -e "${YELLOW}[5/5] 启动 Cloudflared 隧道...${RESET}"
cloudflared tunnel --no-autoupdate run --token "$TOKEN"

echo -e "${GREEN}隧道已启动，请在本地配置 SSH 并连接。${RESET}"