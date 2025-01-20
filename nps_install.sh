#!/bin/bash

# 安装 nps 服务器并设置开机自启动的脚本

# 下载 nps 服务器
echo "正在下载 nps 服务器..."
wget https://github.com/ehang-io/nps/releases/download/v0.26.10/linux_amd64_server.tar.gz

if [ $? -ne 0 ]; then
    echo "下载失败，请检查网络连接或 URL 是否正确。"
    exit 1
fi

# 解压文件
echo "正在解压文件..."
tar -zxvf linux_amd64_server.tar.gz

if [ $? -ne 0 ]; then
    echo "解压失败，请检查文件是否完整。"
    exit 1
fi

# 安装 nps 服务
echo "正在安装 nps 服务..."
sudo ./nps install

if [ $? -ne 0 ]; then
    echo "安装失败，请检查权限或是否已安装。"
    exit 1
fi

# 启动 nps 服务
echo "正在启动 nps 服务..."
sudo ./nps start

if [ $? -ne 0 ]; then
    echo "启动失败，请检查日志文件。"
    exit 1
fi

# 设置开机自启动
echo "正在设置开机自启动..."

# 创建 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/nps.service"
echo "[Unit]
Description=nps Server
After=network.target

[Service]
ExecStart=$(pwd)/nps
WorkingDirectory=$(pwd)
Restart=always
User=root

[Install]
WantedBy=multi-user.target" | sudo tee $SERVICE_FILE > /dev/null

if [ $? -ne 0 ]; then
    echo "创建 systemd 服务文件失败。"
    exit 1
fi

# 重新加载 systemd 配置
sudo systemctl daemon-reload

if [ $? -ne 0 ]; then
    echo "重新加载 systemd 配置失败。"
    exit 1
fi

# 启用 nps 服务
sudo systemctl enable nps

if [ $? -ne 0 ]; then
    echo "启用 nps 服务失败。"
    exit 1
fi

# 启动 nps 服务
sudo systemctl start nps

if [ $? -ne 0 ]; then
    echo "启动 nps 服务失败。"
    exit 1
fi

# 完成
echo "nps 服务器已成功安装并设置为开机自启动！"
echo "Web 管理界面地址: http://服务器IP:8080"
echo "默认用户名: admin"
echo "默认密码: 123（请检查 conf/nps.conf 中的配置）"