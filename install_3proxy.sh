#!/bin/bash

# 脚本功能：检查并安装 3proxy，支持自定义 SOCKS5 代理端口、用户名和密码

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本"
  exit 1
fi

# 定义 3proxy 的安装路径和配置文件路径
PROXY_BIN="/usr/local/bin/3proxy"
PROXY_CONFIG="/etc/3proxy/3proxy.cfg"

# 获取本机外网 IP 地址
get_external_ip() {
  echo "获取本机外网 IP 地址..."
  EXTERNAL_IP=$(curl -s ifconfig.me)
  if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP="无法获取外网 IP"
  fi
  echo "本机外网 IP 地址: $EXTERNAL_IP"
}

# 检查 3proxy 是否已安装
if command -v 3proxy &> /dev/null || [ -f "$PROXY_BIN" ]; then
  echo "3proxy 已安装"
  echo "当前配置文件路径: $PROXY_CONFIG"

  # 直接进入修改配置部分
  echo "正在编辑配置文件..."
  nano "$PROXY_CONFIG"

  # 获取配置信息
  SOCKS_PORT=$(grep -oP 'socks -p\K\d+' "$PROXY_CONFIG")
  PROXY_USER=$(grep -oP 'users \K[^:]+' "$PROXY_CONFIG")
  PROXY_PASS=$(grep -oP 'users .*:CL:\K[^ ]+' "$PROXY_CONFIG")

  # 输出配置信息
  get_external_ip
  echo "SOCKS5 代理端口: $SOCKS_PORT"
  echo "代理用户名: $PROXY_USER"
  echo "代理密码: $PROXY_PASS"

  # 重启 3proxy 服务
  echo "重启 3proxy 服务..."
  pkill 3proxy
  3proxy "$PROXY_CONFIG"
  echo "3proxy 服务已重启。"
else
  echo "3proxy 未安装，开始安装..."

  # 安装依赖
  echo "安装编译依赖..."
  apt update
  apt install -y wget build-essential curl

  # 下载 3proxy 源代码
  echo "下载 3proxy 源代码..."
  wget https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz -O 3proxy-0.9.4.tar.gz

  # 解压并编译
  echo "解压并编译 3proxy..."
  tar -xvzf 3proxy-0.9.4.tar.gz
  cd 3proxy-0.9.4
  make -f Makefile.Linux

  # 安装 3proxy
  echo "安装 3proxy..."
  make -f Makefile.Linux install

  # 创建配置文件目录
  mkdir -p /etc/3proxy

  # 获取用户输入的配置
  echo "请配置 3proxy："
  read -p "请输入 SOCKS5 代理端口（默认 1080）: " SOCKS_PORT
  SOCKS_PORT=${SOCKS_PORT:-1080}

  read -p "请输入代理用户名: " PROXY_USER
  read -p "请输入代理密码: " PROXY_PASS

  # 生成配置文件
  echo "生成配置文件..."
  cat > "$PROXY_CONFIG" <<EOL
daemon
pidfile /var/run/3proxy.pid
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"

auth strong
users $PROXY_USER:CL:$PROXY_PASS

allow * * * *

socks -p$SOCKS_PORT
EOL

  # 创建日志目录
  mkdir -p /var/log/3proxy
  touch /var/log/3proxy/3proxy.log

  echo "3proxy 安装完成。配置文件已生成。"

  # 输出配置信息
  get_external_ip
  echo "SOCKS5 代理端口: $SOCKS_PORT"
  echo "代理用户名: $PROXY_USER"
  echo "代理密码: $PROXY_PASS"

  # 启动 3proxy 服务
  echo "启动 3proxy 服务..."
  3proxy "$PROXY_CONFIG"
  echo "3proxy 服务已启动。"
fi

echo "脚本执行完成。"