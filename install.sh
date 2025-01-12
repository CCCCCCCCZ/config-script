#!/bin/bash

# V2Ray 配置文件路径
V2RAY_CONFIG_FILE="/usr/local/etc/v2ray/config.json"

# 显示菜单
show_menu() {
  echo "请选择要执行的操作："
  echo "1. 安装 V2Ray"
  echo "2. 卸载 V2Ray"
  echo "3. 配置 V2Ray"
  echo "4. 查看 V2Ray"
  echo "5. 退出"
}

# 安装 V2Ray
install_v2ray() {
  apt update
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

# 显示当前配置
show_config() {
  echo "========== 当前配置 =========="

  # 使用 Python 解析 JSON 文件
  python3 - <<EOF
import json

# 读取配置文件
with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

# 显示 Inbounds 和 Outbounds 的绑定关系

for inbound in config.get("inbounds", []):
    inbound_port = inbound.get("port", "未知")
    inbound_protocol = inbound.get("protocol", "未知")
    inbound_tag = inbound.get("tag", "未知")

    # 查找对应的 outbound
    for rule in config.get("routing", {}).get("rules", []):
        if inbound_tag in rule.get("inboundTag", []):
            outbound_tag = rule.get("outboundTag", "未知")
            for outbound in config.get("outbounds", []):
                if outbound.get("tag") == outbound_tag:
                    outbound_protocol = outbound.get("protocol", "未知")
                    if outbound_protocol == "freedom":
                        # 直连 outbound
                        print(f"Inbounds: {inbound_port} {inbound_protocol} => Outbounds: 直连")
                    else:
                        # 普通 outbound
                        servers = outbound.get("settings", {}).get("servers", [])
                        for server in servers:
                            address = server.get("address", "未知")
                            port = server.get("port", "未知")
                            users = server.get("users", [])
                            if users:
                                for user in users:
                                    username = user.get("user", "未知")
                                    password = user.get("pass", "未知")
                                    print(f"Inbounds: {inbound_port} {inbound_protocol} => Outbounds: {address}:{port} {outbound_protocol} 用户名: {username} 密码: {password}")
                            else:
                                print(f"Inbounds: {inbound_port} {inbound_protocol} => Outbounds: {address}:{port} {outbound_protocol} 用户名: 无 密码: 无")
                    break
            break
EOF
echo "=============================="
}

check_v2ray_configure() {
  if [[ ! -f "$V2RAY_CONFIG_FILE" ]]; then
    echo "未找到配置文件，将创建新配置文件。"
    echo '{"inbounds": [], "outbounds": [], "routing": {"rules": []}}' > "$V2RAY_CONFIG_FILE"
  else
    # 检查文件是否为空或仅包含 {}
    if [[ ! -s "$V2RAY_CONFIG_FILE" ]] || [[ "$(cat "$V2RAY_CONFIG_FILE")" == "{}" ]]; then
      echo "配置文件存在但内容为空或仅包含 {}，将写入默认配置。"
      echo '{"inbounds": [], "outbounds": [], "routing": {"rules": []}}' > "$V2RAY_CONFIG_FILE"
    fi
  fi
}

# 配置 V2Ray
configure_v2ray() {
  check_v2ray_configure

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

# 添加配置
add_config() {
  echo "添加配置："

  # 支持的协议列表
  PROTOCOLS=("socks" "http" "shadowsocks" "vmess" "trojan" "vless")

  # 配置 inbound
  echo "请选择 inbound 协议："
  for i in "${!PROTOCOLS[@]}"; do
    echo "$((i+1)). ${PROTOCOLS[$i]}"
  done
  read -p "请输入协议序号 (默认: 1): " INBOUND_PROTOCOL_INDEX
  INBOUND_PROTOCOL_INDEX=${INBOUND_PROTOCOL_INDEX:-1}
  INBOUND_PROTOCOL=${PROTOCOLS[$((INBOUND_PROTOCOL_INDEX-1))]}

  read -p "请输入 inbound 监听端口 (默认: 20000): " INBOUND_PORT
  INBOUND_PORT=${INBOUND_PORT:-20000}

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
    "udp": True,
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
    "udp": True,
    "ip": "0.0.0.0"
  }
}
EOF
    )
  fi

  # 配置 outbound
  echo "请选择 outbound 协议："
  for i in "${!PROTOCOLS[@]}"; do
    echo "$((i+1)). ${PROTOCOLS[$i]}"
  done
  echo "$(( ${#PROTOCOLS[@]} + 1 )). 直连"
  read -p "请输入协议序号 (默认: 1): " OUTBOUND_PROTOCOL_INDEX
  OUTBOUND_PROTOCOL_INDEX=${OUTBOUND_PROTOCOL_INDEX:-1}

  if [[ "$OUTBOUND_PROTOCOL_INDEX" -eq $(( ${#PROTOCOLS[@]} + 1 )) ]]; then
    # 直连选项
    OUTBOUND_PROTOCOL="freedom"
    OUTBOUND_TAG="outbound_$INBOUND_PORT"
    NEW_OUTBOUND=$(cat <<EOF
{
  "tag": "$OUTBOUND_TAG",
  "protocol": "freedom",
  "settings": {}
}
EOF
    )
  else
    # 普通协议
    OUTBOUND_PROTOCOL=${PROTOCOLS[$((OUTBOUND_PROTOCOL_INDEX-1))]}
    OUTBOUND_TAG="outbound_$INBOUND_PORT"

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

    # 生成新的 outbound 配置
    if [[ -n "$OUTBOUND_USER" ]]; then
      NEW_OUTBOUND=$(cat <<EOF
{
  "tag": "$OUTBOUND_TAG",
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
EOF
      )
    else
      NEW_OUTBOUND=$(cat <<EOF
{
  "tag": "$OUTBOUND_TAG",
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
EOF
      )
    fi
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

  # 使用 Python 将新的配置追加到现有配置中
  python3 - <<EOF
import json

# 读取配置文件
with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

# 追加新的 inbound、outbound 和路由规则
config["inbounds"].append($NEW_INBOUND)
config["outbounds"].append($NEW_OUTBOUND)
config["routing"]["rules"].append($NEW_ROUTING_RULE)

# 写回配置文件
with open("$V2RAY_CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
EOF

  echo "配置已添加！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 修改配置
modify_config() {
  show_config

  read -p "请输入要修改的 inbound 端口: " INBOUND_PORT

  # 使用 Python 查找对应的 inbound 配置
  INBOUND_CONFIG=$(python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

inbound_config = next((inbound for inbound in config["inbounds"] if inbound["port"] == $INBOUND_PORT), None)
if inbound_config:
    print(json.dumps(inbound_config))
EOF
  )

  if [[ -z "$INBOUND_CONFIG" ]]; then
    echo "未找到对应的 inbound 配置！"
    return
  fi

  # 使用 Python 查找对应的 outbound 配置
  OUTBOUND_TAG=$(python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

inbound_tag = json.loads('''$INBOUND_CONFIG''')["tag"]
outbound_tag = next((rule["outboundTag"] for rule in config["routing"]["rules"] if inbound_tag in rule.get("inboundTag", [])), None)
print(outbound_tag)
EOF
  )

  OUTBOUND_CONFIG=$(python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

outbound_config = next((outbound for outbound in config["outbounds"] if outbound["tag"] == "$OUTBOUND_TAG"), None)
if outbound_config:
    print(json.dumps(outbound_config))
EOF
  )

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

  # 使用 Python 更新 inbound 配置
  python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

for inbound in config["inbounds"]:
    if inbound["port"] == $INBOUND_PORT:
        inbound["port"] = $NEW_INBOUND_PORT
        if "$NEW_INBOUND_USER" and "$NEW_INBOUND_PASS":
            inbound["settings"]["accounts"][0]["user"] = "$NEW_INBOUND_USER"
            inbound["settings"]["accounts"][0]["pass"] = "$NEW_INBOUND_PASS"
        inbound["settings"]["udp"] = True  # 修正为 Python 的 True

with open("$V2RAY_CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
EOF

  echo "inbound 配置已更新！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 修改 outbound 配置
modify_outbound() {
  # 支持的协议列表
  PROTOCOLS=("socks" "http" "shadowsocks" "vmess" "trojan" "vless" "freedom")

  # 选择新的协议
  echo "请选择新的 outbound 协议："
  for i in "${!PROTOCOLS[@]}"; do
    echo "$((i+1)). ${PROTOCOLS[$i]}"
  done
  read -p "请输入协议序号 (默认: 1): " OUTBOUND_PROTOCOL_INDEX
  OUTBOUND_PROTOCOL_INDEX=${OUTBOUND_PROTOCOL_INDEX:-1}
  NEW_OUTBOUND_PROTOCOL=${PROTOCOLS[$((OUTBOUND_PROTOCOL_INDEX-1))]}

  # 如果选择的协议不是 freedom，则需要输入服务器地址、端口等信息
  if [[ "$NEW_OUTBOUND_PROTOCOL" != "freedom" ]]; then
    read -p "请输入新的 outbound 目标服务器地址 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].address // "无"')): " NEW_OUTBOUND_ADDRESS
    NEW_OUTBOUND_ADDRESS=${NEW_OUTBOUND_ADDRESS:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].address // ""')}

    read -p "请输入新的 outbound 目标服务器端口 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].port // "无"')): " NEW_OUTBOUND_PORT
    NEW_OUTBOUND_PORT=${NEW_OUTBOUND_PORT:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].port // ""')}

    read -p "请输入新的 outbound 用户名 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].user // "无"')): " NEW_OUTBOUND_USER
    NEW_OUTBOUND_USER=${NEW_OUTBOUND_USER:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].user // ""')}

    if [[ -n "$NEW_OUTBOUND_USER" ]]; then
      read -p "请输入新的 outbound 密码 (当前: $(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].pass // "无"')): " NEW_OUTBOUND_PASS
      NEW_OUTBOUND_PASS=${NEW_OUTBOUND_PASS:-$(echo "$OUTBOUND_CONFIG" | jq -r '.settings.servers[0].users[0].pass // ""')}
    else
      NEW_OUTBOUND_PASS=""
    fi
  fi

  # 使用 Python 更新 outbound 配置
  python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

for outbound in config["outbounds"]:
    if outbound["tag"] == "$OUTBOUND_TAG":
        # 更新协议
        outbound["protocol"] = "$NEW_OUTBOUND_PROTOCOL"

        if "$NEW_OUTBOUND_PROTOCOL" == "freedom":
            # 如果是 freedom 协议，清空 settings 中的 servers 和 users
            outbound["settings"] = {}
        else:
            # 其他协议需要配置服务器地址、端口、用户名和密码
            if "servers" not in outbound["settings"]:
                outbound["settings"]["servers"] = [{}]

            # 更新服务器地址和端口
            outbound["settings"]["servers"][0]["address"] = "$NEW_OUTBOUND_ADDRESS"
            outbound["settings"]["servers"][0]["port"] = $NEW_OUTBOUND_PORT

            # 更新用户名和密码
            if "$NEW_OUTBOUND_USER" and "$NEW_OUTBOUND_PASS":
                if "users" not in outbound["settings"]["servers"][0]:
                    outbound["settings"]["servers"][0]["users"] = [{}]
                outbound["settings"]["servers"][0]["users"][0]["user"] = "$NEW_OUTBOUND_USER"
                outbound["settings"]["servers"][0]["users"][0]["pass"] = "$NEW_OUTBOUND_PASS"
            elif "users" in outbound["settings"]["servers"][0]:
                # 如果用户名为空，删除 users 字段
                outbound["settings"]["servers"][0].pop("users", None)
        break

# 写回配置文件
with open("$V2RAY_CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
EOF

  echo "outbound 配置已更新！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 删除配置
delete_config() {
  show_config

  read -p "请输入要删除的 inbound 端口: " INBOUND_PORT

  # 使用 Python 删除配置
  python3 - <<EOF
import json

with open("$V2RAY_CONFIG_FILE", "r") as f:
    config = json.load(f)

# 查找对应的 inbound 配置
inbound_config = next((inbound for inbound in config["inbounds"] if inbound["port"] == $INBOUND_PORT), None)
if inbound_config:
    inbound_tag = inbound_config["tag"]

    # 删除 inbound 配置
    config["inbounds"] = [inbound for inbound in config["inbounds"] if inbound["port"] != $INBOUND_PORT]

    # 查找对应的 outbound 配置
    outbound_tag = next((rule["outboundTag"] for rule in config["routing"]["rules"] if inbound_tag in rule.get("inboundTag", [])), None)
    if outbound_tag:
        # 删除 outbound 配置
        config["outbounds"] = [outbound for outbound in config["outbounds"] if outbound["tag"] != outbound_tag]

    # 删除对应的路由规则
    config["routing"]["rules"] = [rule for rule in config["routing"]["rules"] if inbound_tag not in rule.get("inboundTag", [])]

    # 写回配置文件
    with open("$V2RAY_CONFIG_FILE", "w") as f:
        json.dump(config, f, indent=2)
EOF

  echo "配置已删除并重启 V2Ray 服务！"
  systemctl restart v2ray
  systemctl status v2ray
}

# 主循环
while true; do
  show_menu
  read -p "请输入序号: " CHOICE
  case $CHOICE in
    1) install_v2ray ;;
    2) uninstall_v2ray ;;
    3) configure_v2ray ;;
    4) show_config ;;
    5) exit 0 ;;
    *) echo "无效的选择，请重新输入！" ;;
  esac
done