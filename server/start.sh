#!/bin/bash
set -e

echo "================================================="
echo "    长安大学课表服务中心 (Ubuntu 服务端启动器)"
echo "================================================="

# 切换到脚本所在目录
cd "$(dirname "$0")"

# 检查 Python 3
if ! command -v python3 &> /dev/null; then
    echo "未检测到 python3，请先执行: sudo apt update && sudo apt install -y python3 python3-pip python3-venv"
    exit 1
fi

# 创建并激活虚拟环境 (可选)
if [ ! -d "venv" ]; then
    echo "创建 Python 虚拟环境..."
    python3 -m venv venv || true
fi

if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

# 安装依赖
echo "检查并安装所需依赖..."
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 启动服务
PORT=2543
echo "正在启动 CHD 课表云端服务，监听端口: $PORT"
echo "管理面板地址: http://$(hostname -I | awk '{print $1}'):$PORT/admin"
echo "================================================="

python3 -m uvicorn main:app --host 0.0.0.0 --port $PORT
