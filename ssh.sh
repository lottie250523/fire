#!/usr/bin/env bash

# === 配置颜色 ===
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# === 权限检查 ===
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 root 权限运行本脚本${RESET}" && exit 1

# === 获取 SSH 公钥 ===
while true; do
  read -p "请输入 SSH 公钥（例如 ssh-rsa AAAAB3...）: " SSH_KEY
  if [[ -z "$SSH_KEY" ]]; then
    echo -e "${RED}错误: 公钥不能为空${RESET}"
  elif [[ ! "$SSH_KEY" =~ ^ssh- ]]; then
    echo -e "${RED}错误: 公钥格式不正确${RESET}"
  else
    break
  fi
done

# === 获取 Cloudflared token ===
while true; do
  read -p "请输入 Cloudflared Token: " TOKEN
  if [[ -z "$TOKEN" ]]; then
    echo -e "${RED}错误: Token 不能为空${RESET}"
  else
    break
  fi
done

# === 配置 SSH 服务 ===
echo -e "${YELLOW}[1/3] 配置 SSH 服务...${RESET}"

# 修改 SSH 配置
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# 写入 SSH 公钥
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 停用 socket 激活方式
systemctl disable ssh.socket >/dev/null 2>&1 || true
systemctl stop ssh.socket >/dev/null 2>&1 || true
systemctl unmask ssh >/dev/null 2>&1 || true

# 杀掉可能占用 22 端口的进程
fuser -k 22/tcp >/dev/null 2>&1 || true

# 启动 SSH 服务
systemctl enable ssh >/dev/null 2>&1
systemctl restart ssh

# 检查是否启动成功
if ! systemctl is-active --quiet ssh; then
  echo -e "${RED}错误: SSH 服务启动失败，请检查端口占用或配置文件${RESET}"
  exit 1
fi

# === 启动 Cloudflared 隧道 ===
echo -e "${YELLOW}[2/3] 启动 Cloudflared 隧道...${RESET}"

# 安装 Cloudflared（如未安装）
if ! command -v cloudflared >/dev/null 2>&1; then
  echo -e "${YELLOW}安装 Cloudflared...${RESET}"
  wget -qO cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  dpkg -i cloudflared.deb >/dev/null
  rm -f cloudflared.deb
fi

# 结束已有 cloudflared 隧道
pkill -f "cloudflared tunnel" >/dev/null 2>&1 || true

# 启动新的隧道
nohup cloudflared tunnel --no-autoupdate run --token "$TOKEN" >/dev/null 2>&1 &

echo -e "${GREEN}[3/3] 所有配置完成！${RESET}"
echo ""
echo -e "${GREEN}SSH 登录信息：${RESET}"
echo -e "用户：root"
echo -e "认证方式：SSH 公钥（请确保你已将私钥添加到本地 ssh-agent）"
echo -e "隧道地址：请在 Cloudflare Zero Trust 控制台中查看分配的访问域名"
echo ""
echo -e "${YELLOW}提示：如果未连接，请检查 Cloudflare 后台确认 tunnel 是否在线。${RESET}"