#!/bin/bash

# 更新系统包列表
update_system() {
    echo "正在更新系统包列表..."
    sudo apt update
}

# 安装 V2Ray
install_v2ray() {
    echo "正在安装依赖..."
    sudo apt install -y curl

    echo "正在安装 V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
}

# 配置 V2Ray
configure_v2ray() {
    echo "正在配置 V2Ray..."
    sudo cat > /usr/local/etc/v2ray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 20000,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "123",
            "pass": "123"
          }
        ],
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
}

# 启动 V2Ray 并设置开机启动
start_and_enable_v2ray() {
    echo "正在启动 V2Ray 并设置开机启动..."
    sudo systemctl restart v2ray
    sudo systemctl enable v2ray
}

# 检查 V2Ray 状态
check_v2ray_status() {
    echo "正在检查 V2Ray 状态..."
    sudo systemctl status v2ray
}

# 开放防火墙端口（如果需要）
open_firewall_port() {
    echo "正在开放防火墙端口 20000..."
    sudo ufw allow 20000
    sudo ufw reload
}

# 主函数
main() {
    update_system
    install_v2ray
    configure_v2ray
    start_and_enable_v2ray
    check_v2ray_status
    open_firewall_port

    echo "V2Ray 安装和配置已完成！"
    echo "Inbound 端口: 20000"
    echo "用户名: 123"
    echo "密码: 123"
    echo "Outbound: 直连"
}

# 执行主函数
main