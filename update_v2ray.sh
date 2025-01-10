#!/bin/bash

# V2Ray 配置文件路径
CONFIG_FILE="/usr/local/etc/v2ray/config.json"

# 检查 V2Ray 是否已安装
if ! command -v v2ray &> /dev/null; then
  echo "V2Ray 未安装，正在安装 V2Ray..."
  # 使用官方脚本安装 V2Ray
  bash -c "$(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
  
  # 检查安装是否成功
  if ! command -v v2ray &> /dev/null; then
    echo "V2Ray 安装失败，请手动安装！"
    exit 1
  else
    echo "V2Ray 安装成功！"
  fi
else
  echo "V2Ray 已安装。"
fi

# 备份原始配置文件
if [[ -f "$CONFIG_FILE" ]]; then
  cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
  echo "已备份原始配置文件：$CONFIG_FILE.bak"
else
  echo "未找到配置文件，将创建新配置文件。"
fi

# 支持的协议列表
PROTOCOLS=(
  "socks"
  "http"
  "shadowsocks"
  "vmess"
  "trojan"
  "vless"
)

# 显示菜单
echo "请选择要修改的配置："
echo "1. 修改 inbound 配置"
echo "2. 修改 outbound 配置"
read -p "请输入序号 (默认: 1): " MENU_CHOICE
MENU_CHOICE=${MENU_CHOICE:-1}

# 修改 inbound 配置
if [[ "$MENU_CHOICE" == "1" ]]; then
  # 显示协议列表
  echo "请选择 inbound 协议："
  for i in "${!PROTOCOLS[@]}"; do
    echo "$((i+1)). ${PROTOCOLS[$i]}"
  done

  # 提示用户选择 inbound 协议
  read -p "请输入 inbound 协议序号 (默认: 1): " INBOUND_PROTOCOL_INDEX
  INBOUND_PROTOCOL_INDEX=${INBOUND_PROTOCOL_INDEX:-1}
  INBOUND_PROTOCOL=${PROTOCOLS[$((INBOUND_PROTOCOL_INDEX-1))]}

  # 提示用户输入 inbound 配置
  read -p "请输入 inbound 监听端口 (默认: 5000): " INBOUND_PORT
  INBOUND_PORT=${INBOUND_PORT:-5000}

  read -p "请输入 inbound 用户名 (默认: 123): " INBOUND_USER
  INBOUND_USER=${INBOUND_USER:-123}

  read -p "请输入 inbound 密码 (默认: 123): " INBOUND_PASS
  INBOUND_PASS=${INBOUND_PASS:-123}

  # 读取现有的 outbound 配置
  OUTBOUND_PROTOCOL=$(grep -oP '"protocol":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '2p')
  OUTBOUND_ADDRESS=$(grep -oP '"address":\s*"\K[^"]+' "$CONFIG_FILE")
  OUTBOUND_PORT=$(grep -oP '"port":\s*\K[0-9]+' "$CONFIG_FILE" | sed -n '2p')
  OUTBOUND_USER=$(grep -oP '"user":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '2p')
  OUTBOUND_PASS=$(grep -oP '"pass":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '2p')

  # 生成新的配置文件
  cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": $INBOUND_PORT,
      "protocol": "$INBOUND_PROTOCOL",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$INBOUND_USER",
            "pass": "$INBOUND_PASS"
          }
        ],
        "udp": true,
        "ip": "0.0.0.0"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "$OUTBOUND_PROTOCOL",
      "settings": {
        "servers": [
          {
            "address": "$OUTBOUND_ADDRESS",
            "port": $OUTBOUND_PORT,
            "users": [
              {
                "user": "$OUTBOUND_USER",
                "pass": "$OUTBOUND_PASS"
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF

# 修改 outbound 配置
elif [[ "$MENU_CHOICE" == "2" ]]; then
  # 显示协议列表
  echo "请选择 outbound 协议："
  for i in "${!PROTOCOLS[@]}"; do
    echo "$((i+1)). ${PROTOCOLS[$i]}"
  done

  # 提示用户选择 outbound 协议
  read -p "请输入 outbound 协议序号 (默认: 1): " OUTBOUND_PROTOCOL_INDEX
  OUTBOUND_PROTOCOL_INDEX=${OUTBOUND_PROTOCOL_INDEX:-1}
  OUTBOUND_PROTOCOL=${PROTOCOLS[$((OUTBOUND_PROTOCOL_INDEX-1))]}

  # 验证 IP 地址
  while true; do
    read -p "请输入 outbound 目标服务器地址: " OUTBOUND_ADDRESS
    if [[ "$OUTBOUND_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      break
    else
      echo "错误：请输入有效的 IP 地址！"
    fi
  done

  # 验证端口
  while true; do
    read -p "请输入 outbound 目标服务器端口: " OUTBOUND_PORT
    if [[ "$OUTBOUND_PORT" =~ ^[0-9]+$ ]] && [ "$OUTBOUND_PORT" -ge 1 ] && [ "$OUTBOUND_PORT" -le 65535 ]; then
      break
    else
      echo "错误：请输入有效的端口号（1-65535）！"
    fi
  done

  # 提示用户输入 outbound 用户名
  read -p "请输入 outbound 用户名（留空则启用无验证）: " OUTBOUND_USER

  # 如果用户名不为空，则提示输入密码
  if [[ -n "$OUTBOUND_USER" ]]; then
    read -p "请输入 outbound 密码: " OUTBOUND_PASS
  else
    OUTBOUND_PASS=""
  fi

  # 读取现有的 inbound 配置
  INBOUND_PORT=$(grep -oP '"port":\s*\K[0-9]+' "$CONFIG_FILE" | sed -n '1p')
  INBOUND_PROTOCOL=$(grep -oP '"protocol":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '1p')
  INBOUND_USER=$(grep -oP '"user":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '1p')
  INBOUND_PASS=$(grep -oP '"pass":\s*"\K[^"]+' "$CONFIG_FILE" | sed -n '1p')

  # 生成新的配置文件
  if [[ -n "$OUTBOUND_USER" ]]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": $INBOUND_PORT,
      "protocol": "$INBOUND_PROTOCOL",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$INBOUND_USER",
            "pass": "$INBOUND_PASS"
          }
        ],
        "udp": true,
        "ip": "0.0.0.0"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "$OUTBOUND_PROTOCOL",
      "settings": {
        "servers": [
          {
            "address": "$OUTBOUND_ADDRESS",
            "port": $OUTBOUND_PORT,
            "users": [
              {
                "user": "$OUTBOUND_USER",
                "pass": "$OUTBOUND_PASS"
              }
            ]
          }
        ]
      }
    }
  ]
}
EOF
  else
    cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": $INBOUND_PORT,
      "protocol": "$INBOUND_PROTOCOL",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$INBOUND_USER",
            "pass": "$INBOUND_PASS"
          }
        ],
        "udp": true,
        "ip": "0.0.0.0"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "$OUTBOUND_PROTOCOL",
      "settings": {
        "servers": [
          {
            "address": "$OUTBOUND_ADDRESS",
            "port": $OUTBOUND_PORT
          }
        ]
      }
    }
  ]
}
EOF
  fi
fi

# 重启 V2Ray 服务
systemctl restart v2ray

# 检查 V2Ray 状态
systemctl status v2ray

echo "V2Ray 配置文件已更新并重启！"