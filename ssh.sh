#!/usr/bin/env bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检查 root 权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 sudo -i 获取 root 权限后再执行此脚本${RESET}" && exit 1

# 提示用户输入 Cloudflared token 和 root 密码
read -p "请输入 Cloudflared Tunnel Token: " TOKEN

while true; do
  read -p "请输入 root 密码（至少10位）: " PASSWORD
  if [[ -z "$PASSWORD" || ${#PASSWORD} -lt 10 ]]; then
    echo -e "${RED}错误: 密码不能为空且长度不得少于10位${RESET}"
  else
    break
  fi
done

echo -e "${YELLOW}[1/4] 配置 SSH 服务，启用密码登录和 root 登录...${RESET}"

# 配置 SSH 服务
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "root:$PASSWORD" | chpasswd

# 解锁并启动 SSH 服务
echo -e "${YELLOW}[2/4] 解锁 SSH 服务并尝试启动...${RESET}"
systemctl unmask ssh 2>/dev/null || true
systemctl start ssh 2>/dev/null || true
systemctl enable ssh 2>/dev/null || true

# 下载 Cloudflared
echo -e "${YELLOW}[3/4] 下载并启动 Cloudflared 隧道...${RESET}"
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# 启动 Cloudflared 隧道
nohup cloudflared tunnel --no-autoupdate run --token "$TOKEN" >/tmp/cloudflared.log 2>&1 &

echo -e "${GREEN}[4/4] 所有配置完成，请在 Cloudflare 控制台查看 SSH 地址（.trycloudflare.com 子域名）${RESET}"
echo ""
echo -e "${GREEN}SSH 用户: root${RESET}"
echo -e "${GREEN}SSH 密码: $PASSWORD${RESET}"
echo ""
echo -e "${YELLOW}注意: 如需停止 Cloudflared，可运行: pkill -f cloudflared${RESET}"