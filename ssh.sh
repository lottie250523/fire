#!/usr/bin/env bash

# 颜色定义
RED="\033[31m" GREEN="\033[32m" YELLOW="\033[33m" RESET="\033[0m"

# 检查是否为 root
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 请使用 sudo -i 获得 root 权限${RESET}" && exit 1

# 设置 root 密码
while true; do
  read -p "设置 root 密码 (至少10位): " PASSWORD
  [[ -z "$PASSWORD" ]] && echo -e "${RED}错误: 密码不能为空${RESET}" && continue
  [[ ${#PASSWORD} -lt 10 ]] && echo -e "${RED}错误: 密码过短${RESET}" && continue
  break
done

# 配置 SSH 服务
echo -e "${YELLOW}配置 SSH 服务...${RESET}"
sed -i 's/^#\?\(PermitRootLogin\s*\).*$/\1yes/' /etc/ssh/sshd_config
sed -i 's/^#\?\(PasswordAuthentication\s*\).*$/\1yes/' /etc/ssh/sshd_config
echo "root:$PASSWORD" | chpasswd
systemctl unmask ssh 2>/dev/null || true
systemctl restart ssh 2>/dev/null || true

# 获取 Cloudflare Tunnel Token
while true; do
  read -p "请输入 Cloudflare Tunnel Token: " TOKEN
  [[ -z "$TOKEN" ]] && echo -e "${RED}错误: Token 不能为空${RESET}" || break
done

# 安装 cloudflared
if ! command -v cloudflared >/dev/null 2>&1; then
  echo -e "${YELLOW}安装 cloudflared...${RESET}"
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
  dpkg -i /tmp/cloudflared.deb >/dev/null || apt -f install -y >/dev/null
fi

# 启动 cloudflared 隧道
echo -e "${YELLOW}启动 Cloudflare Tunnel...${RESET}"
pkill -f "cloudflared tunnel" 2>/dev/null || true
nohup cloudflared tunnel --no-autoupdate run --token "$TOKEN" >/tmp/cloudflared.log 2>&1 &

# 输出连接信息
echo -e "${GREEN}===== SSH Cloudflare Tunnel 启动成功 =====${RESET}"
echo -e "${GREEN}SSH 用户: ${RESET}root"
echo -e "${GREEN}SSH 密码: ${RESET}$PASSWORD"
echo -e "${YELLOW}请登录 Cloudflare Zero Trust 后台查看你的 SSH 公网地址${RESET}"
echo -e "${YELLOW}日志文件: /tmp/cloudflared.log${RESET}"