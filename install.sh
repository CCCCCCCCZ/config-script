#!/bin/bash

# V2Ray 配置文件路径
V2RAY_CONFIG_FILE="/usr/local/etc/v2ray/config.json"

# 显示菜单
show_menu() {
  echo "请选择要执行的操作："
  echo "1. 安装 V2Ray"
  echo "2. 卸载 V2Ray"
  echo "3. 配置 V2Ray"
  echo "4. 退出"
}

# 安装 V2Ray
install_v2ray() {
  if ! command -v v2ray &> /dev/null; then
    echo "V2Ray 未安装，正在安装 V2Ray..."
    bash -c "$(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
    
    if ! command -v v2ray &> /dev/null; then
      echo "V2Ray 安装失败，请手动安装！"
      exit 1
    else
      echo "V2Ray 安装成功！"
      systemctl enable v2ray --now
      echo "V2Ray 服务已启用并启动。"
    fi
  else
    echo "V2Ray 已安装。"
  fi
}

# 卸载 V2Ray
uninstall_v2ray() {
  if command -v v2ray &> /dev/null; then
    echo "正在卸载 V2Ray..."
    bash -c "$(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)" -- remove
    echo "V2Ray 已卸载。"
  else
    echo "V2Ray 未安装。"
  fi
}

# 配置 V2Ray
configure_v2ray() {
  if [[ ! -f "$V2RAY_CONFIG_FILE" ]]; then
    echo "未找到配置文件，将创建新配置文件。"
    echo '{"inbounds": [], "outbounds": [], "routing": {"rules": []}}' > "$V2RAY_CONFIG_FILE"
  fi

  while true; do
    echo "请选择要执行的操作："
    echo "1. 添加配置"
    echo "2. 修改配置"
    echo "3. 删除配置"
    echo "4. 返回主菜单"
    read -p "请输入序号: " CONFIG_CHOICE

    case $CONFIG_CHOICE in
      1)
        add_config
        ;;
      2)
        modify_config
        ;;
      3)
        delete_config
        ;;
      4)
        return
        ;;
      *)
        echo "无效的选择，请重新输入！"
        ;;
    esac
  done
}

add_config() {
  echo "添加配置："

  # 配置 inbound
  read -p "请输入 inbound 协议 (默认: socks): " INBOUND_PROTOCOL
  INBOUND_PROTOCOL=${INBOUND_PROTOCOL:-socks}

  read -p "请输入 inbound 监听端口 (默认: 5000): " INBOUND_PORT
  INBOUND_PORT=${INBOUND_PORT:-5000}

  read -p "请输入 inbound 用户名 (留空则不需要验证): " INBOUND_USER
  INBOUND_USER=${INBOUND_USER:-123}

  read -p "请输入 inbound 密码 (留空则不需要验证): " INBOUND_PASS
  INBOUND_PASS=${INBOUND_PASS:-123}

  INBOUND_TAG="inbound_$INBOUND_PORT"

  # 生成新的 inbound 配置
  if [[ -z "$INBOUND_USER" || -z "$INBOUND_PASS" ]]; then
    NEW_INBOUND=$(cat <<EOF
{
  "tag": "$INBOUND_TAG",
  "port": $INBOUND_PORT,
  "protocol": "$INBOUND_PROTOCOL",
  "settings": {
    "udp": true,
    "ip": "0.0.0.0"
  }
}
EOF
    )
  else
    NEW_INBOUND=$(cat <<EOF
{
  "tag": "$INBOUND_TAG",
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
EOF
    )
  fi

  # 配置 outbound
  while true; do
    read -p "请输入 outbound 目标服务器地址: " OUTBOUND_ADDRESS
    if [[ "$OUTBOUND_ADDRESS" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      break
    else
      echo "错误：请输入有效的 IP 地址！"
    fi
  done

  while true; do
    read -p "请输入 outbound 目标服务器端口: " OUTBOUND_PORT
    if [[ "$OUTBOUND_PORT" =~ ^[0-9]+$ ]] && [ "$OUTBOUND_PORT" -ge 1 ] && [ "$OUTBOUND_PORT" -le 65535 ]; then
      break
    else
      echo "错误：请输入有效的端口号（1-65535）！"
    fi
  done

  read -p "请输入 outbound 用户名（留空则启用无验证）: " OUTBOUND_USER

  if [[ -n "$OUTBOUND_USER" ]]; then
    read -p "请输入 outbound 密码: " OUTBOUND_PASS
  else
    OUTBOUND_PASS=""
  fi

  OUTBOUND_TAG="outbound_$INBOUND_PORT"

  # 生成新的 outbound 配置
  if [[ -n "$OUTBOUND_USER" ]]; then
    NEW_OUTBOUND=$(cat <<EOF
{
  "tag": "$OUTBOUND_TAG",
  "protocol": "$INBOUND_PROTOCOL",
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
EOF
    )
  else
    NEW_OUTBOUND=$(cat <<EOF
{
  "tag": "$OUTBOUND_TAG",
  "protocol": "$INBOUND_PROTOCOL",
  "settings": {
    "servers": [
      {
        "address": "$OUTBOUND_ADDRESS",
        "port": $OUTBOUND_PORT
      }
    ]
  }
}
EOF
    )
  fi

  # 生成新的 routing 规则
  NEW_ROUTING_RULE=$(cat <<EOF
{
  "type": "field",
  "inboundTag": ["$INBOUND_TAG"],
  "outboundTag": "$OUTBOUND_TAG"
}
EOF
  )

  # 使用 jq 将新的配置追加到现有配置中
  if ! command -v jq &> /dev/null; then
    echo "jq 未安装，正在安装 jq..."
    apt update && apt install -y jq
  fi

  # 追加新的 inbound、outbound 和路由规则
  echo "正在追加 inbound 配置..."
  jq ".inbounds += [$NEW_INBOUND]" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  if [ $? -eq 0 ]; then
    echo "inbound 配置已成功写入文件。"
  else
    echo "inbound 配置写入失败！"
  fi

  echo "正在追加 outbound 配置..."
  jq ".outbounds += [$NEW_OUTBOUND]" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  if [ $? -eq 0 ]; then
    echo "outbound 配置已成功写入文件。"
  else
    echo "outbound 配置写入失败！"
  fi

  echo "正在追加 routing 规则..."
  jq ".routing.rules += [$NEW_ROUTING_RULE]" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  if [ $? -eq 0 ]; then
    echo "routing 规则已成功写入文件。"
  else
    echo "routing 规则写入失败！"
  fi

  echo "配置已添加！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 修改配置
modify_config() {
  echo "当前配置："
  echo "========== Inbounds => Outbounds =========="
  jq -r '.inbounds[] | .tag as $inbound_tag | .port as $inbound_port | 
         . as $inbound | 
         .routing.rules[] | select(.inboundTag[] == $inbound_tag) | 
         .outboundTag as $outbound_tag | 
         . as $rule | 
         .outbounds[] | select(.tag == $outbound_tag) | 
         "Inbounds: \($inbound_port) => Outbounds: \(.settings.servers[0].address):\(.settings.servers[0].port)"' \
         "$V2RAY_CONFIG_FILE"

  read -p "请输入要修改的 inbound 端口: " INBOUND_PORT

  # 查找对应的 inbound 配置
  INBOUND_CONFIG=$(jq -r ".inbounds[] | select(.port == $INBOUND_PORT)" "$V2RAY_CONFIG_FILE")
  if [[ -z "$INBOUND_CONFIG" ]]; then
    echo "未找到对应的 inbound 配置！"
    return
  fi

  # 查找对应的 outbound 配置
  OUTBOUND_TAG=$(jq -r ".routing.rules[] | select(.inboundTag[] == \"$(echo "$INBOUND_CONFIG" | jq -r '.tag')\") | .outboundTag" "$V2RAY_CONFIG_FILE")
  OUTBOUND_CONFIG=$(jq -r ".outbounds[] | select(.tag == \"$OUTBOUND_TAG\")" "$V2RAY_CONFIG_FILE")
  if [[ -z "$OUTBOUND_CONFIG" ]]; then
    echo "未找到对应的 outbound 配置！"
    return
  fi

  # 显示当前配置
  echo "当前 inbound 配置："
  echo "$INBOUND_CONFIG"
  echo "当前 outbound 配置："
  echo "$OUTBOUND_CONFIG"

  # 选择修改 inbound 或 outbound
  echo "请选择要修改的配置："
  echo "1. 修改 inbound 配置"
  echo "2. 修改 outbound 配置"
  echo "3. 返回"
  read -p "请输入序号: " MODIFY_CHOICE

  case $MODIFY_CHOICE in
    1)
      modify_inbound
      ;;
    2)
      modify_outbound
      ;;
    3)
      return
      ;;
    *)
      echo "无效的选择，请重新输入！"
      ;;
  esac
}

# 修改 inbound 配置
modify_inbound() {
  read -p "请输入新的 inbound 监听端口 (当前: $(echo "$INBOUND_CONFIG" | jq -r '.port')): " NEW_INBOUND_PORT
  NEW_INBOUND_PORT=${NEW_INBOUND_PORT:-$(echo "$INBOUND_CONFIG" | jq -r '.port')}

  read -p "请输入新的 inbound 用户名 (当前: $(echo "$INBOUND_CONFIG" | jq -r '.settings.accounts[0].user // "无"')): " NEW_INBOUND_USER
  NEW_INBOUND_USER=${NEW_INBOUND_USER:-$(echo "$INBOUND_CONFIG" | jq -r '.settings.accounts[0].user // ""')}

  read -p "请输入新的 inbound 密码 (当前: $(echo "$INBOUND_CONFIG" | jq -r '.settings.accounts[0].pass // "无"')): " NEW_INBOUND_PASS
  NEW_INBOUND_PASS=${NEW_INBOUND_PASS:-$(echo "$INBOUND_CONFIG" | jq -r '.settings.accounts[0].pass // ""')}

  # 更新 inbound 配置
  jq "(.inbounds[] | select(.port == $INBOUND_PORT) | .port) = $NEW_INBOUND_PORT |
      (.inbounds[] | select(.port == $INBOUND_PORT) | .settings.accounts[0].user) = \"$NEW_INBOUND_USER\" |
      (.inbounds[] | select(.port == $INBOUND_PORT) | .settings.accounts[0].pass) = \"$NEW_INBOUND_PASS\"" \
      "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"

  echo "inbound 配置已更新！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 修改 outbound 配置
modify_outbound() {
  read -p "请输入新的 outbound 目标服务器地址 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].address')): " NEW_OUTBOUND_ADDRESS
  NEW_OUTBOUND_ADDRESS=${NEW_OUTBOUND_ADDRESS:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].address')}

  read -p "请输入新的 outbound 目标服务器端口 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].port')): " NEW_OUTBOUND_PORT
  NEW_OUTBOUND_PORT=${NEW_OUTBOUND_PORT:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].port')}

  read -p "请输入新的 outbound 用户名 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].user // "无"')): " NEW_OUTBOUND_USER
  NEW_OUTBOUND_USER=${NEW_OUTBOUND_USER:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].user // ""')}

  if [[ -n "$NEW_OUTBOUND_USER" ]]; then
    read -p "请输入新的 outbound 密码 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].pass // "无"')): " NEW_OUTBOUND_PASS
    NEW_OUTBOUND_PASS=${NEW_OUTBOUND_PASS:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].pass // ""')}
  else
    NEW_OUTBOUND_PASS=""
  fi

  # 更新 outbound 配置
  if [[ -n "$NEW_OUTBOUND_USER" ]]; then
    jq "(.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].address) = \"$NEW_OUTBOUND_ADDRESS\" |
        (.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].port) = $NEW_OUTBOUND_PORT |
        (.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].users[0].user) = \"$NEW_OUTBOUND_USER\" |
        (.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].users[0].pass) = \"$NEW_OUTBOUND_PASS\"" \
        "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  else
    jq "(.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].address) = \"$NEW_OUTBOUND_ADDRESS\" |
        (.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].port) = $NEW_OUTBOUND_PORT |
        del(.outbounds[] | select(.tag == \"$OUTBOUND_TAG\") | .settings.servers[0].users)" \
        "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  fi

  echo "outbound 配置已更新！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 删除配置
delete_config() {
  echo "当前配置："
  echo "========== Inbounds => Outbounds =========="
  jq -r '.inbounds[] | .tag as $inbound_tag | .port as $inbound_port | 
         . as $inbound | 
         .routing.rules[] | select(.inboundTag[] == $inbound_tag) | 
         .outboundTag as $outbound_tag | 
         . as $rule | 
         .outbounds[] | select(.tag == $outbound_tag) | 
         "Inbounds: \($inbound_port) => Outbounds: \(.settings.servers[0].address):\(.settings.servers[0].port)"' \
         "$V2RAY_CONFIG_FILE"

  read -p "请输入要删除的 inbound 端口: " INBOUND_PORT

  # 查找对应的 inbound 配置
  INBOUND_CONFIG=$(jq -r ".inbounds[] | select(.port == $INBOUND_PORT)" "$V2RAY_CONFIG_FILE")
  if [[ -z "$INBOUND_CONFIG" ]]; then
    echo "未找到对应的 inbound 配置！"
    return
  fi

  # 查找对应的 outbound 配置
  OUTBOUND_TAG=$(jq -r ".routing.rules[] | select(.inboundTag[] == \"$(echo "$INBOUND_CONFIG" | jq -r '.tag')\") | .outboundTag" "$V2RAY_CONFIG_FILE")
  OUTBOUND_CONFIG=$(jq -r ".outbounds[] | select(.tag == \"$OUTBOUND_TAG\")" "$V2RAY_CONFIG_FILE")
  if [[ -z "$OUTBOUND_CONFIG" ]]; then
    echo "未找到对应的 outbound 配置！"
    return
  fi

  # 删除 inbound 配置
  jq "del(.inbounds[] | select(.port == $INBOUND_PORT))" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  echo "已删除 inbound 配置：$INBOUND_PORT"

  # 删除 outbound 配置
  jq "del(.outbounds[] | select(.tag == \"$OUTBOUND_TAG\"))" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  echo "已删除 outbound 配置：$OUTBOUND_TAG"

  # 删除对应的路由规则
  jq "del(.routing.rules[] | select(.inboundTag[] == \"$(echo "$INBOUND_CONFIG" | jq -r '.tag')\"))" "$V2RAY_CONFIG_FILE" > tmp.json && mv tmp.json "$V2RAY_CONFIG_FILE"
  echo "已删除与 $INBOUND_PORT 相关的路由规则。"

  systemctl restart v2ray
  systemctl status v2ray
  echo "配置已删除并重启 V2Ray 服务！"
}

# 主循环
while true; do
  show_menu
  read -p "请输入序号: " CHOICE
  case $CHOICE in
    1) install_v2ray ;;
    2) uninstall_v2ray ;;
    3) configure_v2ray ;;
    4) exit 0 ;;
    *) echo "无效的选择，请重新输入！" ;;
  esac
done