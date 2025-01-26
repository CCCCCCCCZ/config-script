#!/bin/bash
set -e

# 配置区 (按需修改)
FRP_VERSION="0.61.1"
BIND_PORT="7000"
DASHBOARD_PORT="7500"
DASHBOARD_USER="admin"
DASHBOARD_PWD=$(date +%s | sha256sum | base64 | head -c 16)  # 随机生成密码
TOKEN=$(openssl rand -hex 16)

# 检测root权限
if [ "$(id -u)" != "0" ]; then
   echo "错误: 请使用sudo或以root身份运行此脚本" >&2
   exit 1
fi

# 安装基础依赖
if ! command -v wget &> /dev/null; then
    apt-get update && apt-get install -y wget
fi

# 工作目录
WORK_DIR="/tmp/frp_install_$(date +%s)"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 下载并解压新版FRP
echo "正在下载FRP v${FRP_VERSION}..."
if ! wget -q --show-progress https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz; then
    echo "下载失败，请检查版本号或网络连接" >&2
    exit 1
fi

tar -zxvf frp_${FRP_VERSION}_linux_amd64.tar.gz > /dev/null

# 文件部署
echo "安装文件中..."
mkdir -p /etc/frp
cp frp_${FRP_VERSION}_linux_amd64/frps /usr/local/bin/
chmod +x /usr/local/bin/frps

# 生成TOML格式配置文件
cat > /etc/frp/frps.toml <<EOF
[common]
bindPort = ${BIND_PORT}
token = "${TOKEN}"

[webServer]
addr = "0.0.0.0"
port = ${DASHBOARD_PORT}
user = "${DASHBOARD_USER}"
password = "${DASHBOARD_PWD}"
EOF

# 创建系统服务
cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml

[Install]
WantedBy=multi-user.target
EOF

# 重载服务配置
systemctl daemon-reload

# 防火墙设置
if ufw status | grep -q active; then
    ufw allow ${BIND_PORT}/tcp
    ufw allow ${DASHBOARD_PORT}/tcp
    echo "防火墙规则已添加"
fi

# 启动服务
systemctl enable --now frps

# 清理临时文件
rm -rf $WORK_DIR

# 输出安装信息
echo -e "\n\033[32mFRP服务端部署完成\033[0m"
echo -e "访问仪表板: \033[34mhttp://服务器IP:${DASHBOARD_PORT}\033[0m"
echo -e "用户名: ${DASHBOARD_USER}"
echo -e "密码: \033[31m${DASHBOARD_PWD}\033[0m"
echo -e "客户端连接令牌: \033[31m${TOKEN}\033[0m"
echo -e "验证命令: systemctl status frps"