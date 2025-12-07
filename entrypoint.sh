#!/bin/bash

# 输出所有命令便于调试
echo "========== 容器启动 =========="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "工作目录: $(pwd)"
echo "Python 版本: $(python --version 2>&1)"

# 运行模式
MODE="${1:-${RUN_MODE:-scheduler}}"
SCRIPT="${2:-auto_checkin.py}"

echo "运行模式: $MODE"
echo "环境变量:"
echo "  CHECKIN_USERNAME: ${CHECKIN_USERNAME:+已设置}"
echo "  CHECKIN_PASSWORD: ${CHECKIN_PASSWORD:+已设置}"
echo "  WXPUSHER_APP_TOKEN: ${WXPUSHER_APP_TOKEN:+已设置}"

# 标记容器环境
export CONTAINER_ENV=true

# 检查必需环境变量
if [ -z "$CHECKIN_USERNAME" ] || [ -z "$CHECKIN_PASSWORD" ]; then
    echo "❌ 错误：必须设置 CHECKIN_USERNAME 和 CHECKIN_PASSWORD 环境变量"
    echo "容器将保持运行以便调试..."
    # 保持容器运行，方便查看日志
    tail -f /dev/null
fi

# 生成 config.json
cat > config.json << EOF
{
  "username": "$CHECKIN_USERNAME",
  "password": "$CHECKIN_PASSWORD",
  "wxpusher_app_token": "${WXPUSHER_APP_TOKEN:-}",
  "wxpusher_uid": "${WXPUSHER_UID:-}"
}
EOF

echo "config.json 已生成"

case "$MODE" in
    scheduler)
        echo "📅 启动定时调度器..."
        exec python scheduler.py
        ;;
    once)
        echo "📅 一次性运行: $SCRIPT"
        exec python "$SCRIPT"
        ;;
    checkin)
        echo "📅 运行打卡"
        exec python auto_checkin.py
        ;;
    report)
        echo "📅 运行日报"
        exec python auto_daily_report.py
        ;;
    *)
        echo "❌ 未知模式: $MODE，使用默认 scheduler"
        exec python scheduler.py
        ;;
esac
