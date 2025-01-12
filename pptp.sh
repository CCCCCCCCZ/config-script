#!/bin/bash

# 显示菜单
function show_menu() {
    echo "请选择一个操作:"
    echo "1. 安装PPTP"
    echo "2. 卸载PPTP"
    echo "3. 配置PPTP"
    echo "4. 退出"
}

# 安装PPTP
function install_pptp() {
    echo "正在更新系统并安装PPTP客户端..."
    sudo apt update
    sudo apt install -y pptp-linux
    echo "PPTP客户端安装完成！"
}

# 卸载PPTP
function uninstall_pptp() {
    echo "正在卸载PPTP客户端..."
    sudo apt remove -y pptp-linux
    sudo rm -f /etc/ppp/peers/myvpn
    sudo rm -f /etc/ppp/chap-secrets
    sudo rm -f /etc/ppp/ip-up.d/setroute
    echo "PPTP客户端已卸载！"
}

# 配置PPTP
function configure_pptp() {
    # 提示用户输入VPN服务器的IP地址、用户名和密码
    read -p "请输入VPN服务器的IP地址: " VPN_SERVER
    read -p "请输入VPN用户名: " VPN_USERNAME
    read -p "请输入VPN密码: " VPN_PASSWORD

    # 创建PPTP配置文件
    echo "正在配置PPTP连接..."
    sudo tee /etc/ppp/peers/myvpn > /dev/null <<EOF
pty "pptp $VPN_SERVER --nolaunchpppd"
name $VPN_USERNAME
remotename PPTP
require-mppe-128
file /etc/ppp/options.pptp
ipparam myvpn
EOF

    # 配置认证信息
    echo "正在配置认证信息..."
    sudo tee /etc/ppp/chap-secrets > /dev/null <<EOF
$VPN_USERNAME PPTP $VPN_PASSWORD *
EOF

    # 配置全局VPN路由
    echo "正在配置全局VPN路由..."
    sudo tee /etc/ppp/ip-up.d/setroute > /dev/null <<EOF
#!/bin/sh
/sbin/route add default dev ppp0
EOF

    # 赋予脚本执行权限
    sudo chmod +x /etc/ppp/ip-up.d/setroute

    # 启动PPTP连接
    echo "正在启动PPTP连接..."
    sudo pon myvpn

    # 检查连接状态
    echo "VPN连接已启动，检查状态中..."
    sleep 5
    ifconfig ppp0
    route -n

    echo "PPTP配置完成！所有流量将通过VPN路由。"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 (1-4): " OPTION
    case $OPTION in
        1)
            install_pptp
            ;;
        2)
            uninstall_pptp
            ;;
        3)
            configure_pptp
            ;;
        4)
            echo "退出脚本。"
            break
            ;;
        *)
            echo "无效选项，请重新输入！"
            ;;
    esac
    echo ""
done