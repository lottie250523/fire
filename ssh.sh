#!/usr/bin/env bash

# === 配置颜色 ===
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# === 权限检查 ===
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 root 权限运行本脚本${RESET}" && exit 1

# === 获取 root 密码 ===
while true; do
  read -p "请输入 root 密码 (至少10位): " PASSWORD
  if [[ -z "$PASSWORD" ]]; then
    echo -e "${RED}错误: 密码不能为空${RESET}"
  elif [[ ${#PASSWORD} -lt 10 ]]; then
    echo -e "${RED}错误: 密码长度不足10位${RESET}"
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
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo root:$PASSWORD | chpasswd

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
echo -e "密码：$PASSWORD"
echo -e "隧道地址：请在 Cloudflare Zero Trust 控制台中查看分配的访问域名"
echo ""
echo -e "${YELLOW}提示：如果未连接，请检查 Cloudflare 后台确认 tunnel 是否在线。${RESET}"