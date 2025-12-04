#!/bin/bash
set -e

SCRIPT=${1:-auto_checkin.py}
echo "🚀 启动容器，运行脚本: $SCRIPT"

# 检测 GitHub Actions 环境（兼容现有日志逻辑）
if [ "$GITHUB_ACTIONS" = "true" ]; then
    export GITHUB_ACTIONS=true
fi

# 检查必需环境变量
if [ -z "$CHECKIN_USERNAME" ] || [ -z "$CHECKIN_PASSWORD" ]; then
    echo "❌ 错误：必须设置 CHECKIN_USERNAME 和 CHECKIN_PASSWORD 环境变量"
    exit 1
fi

# 生成 config.json（兼容现有代码）
if [ ! -f config.json ]; then
    cat > config.json << EOF
{
  "username": "$CHECKIN_USERNAME",
  "password": "$CHECKIN_PASSWORD",
  "wxpusher_app_token": "${WXPUSHER_APP_TOKEN:-}",
  "wxpusher_uid": "${WXPUSHER_UID:-}"
}
EOF
fi

# 运行指定脚本
echo "📋 环境变量检查："
echo "  用户名: ${CHECKIN_USERNAME:0:3}***"
echo "  WxPusher: $( [ -n "$WXPUSHER_APP_TOKEN" ] && echo "已配置" || echo "未配置" )"
echo "📅 开始执行: python $SCRIPT"
exec python "$SCRIPT"
