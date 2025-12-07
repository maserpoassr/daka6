#!/bin/bash
set -e

# 运行模式: scheduler (定时调度) / once (一次性运行)
# 优先命令行参数，其次 RUN_MODE 环境变量，默认 scheduler
MODE="${1:-${RUN_MODE:-scheduler}}"
SCRIPT="${2:-auto_checkin.py}"

# 确保 MODE 不为空
if [ -z "$MODE" ]; then
    MODE="scheduler"
fi

echo "🚀 启动容器"
echo "📋 运行模式: $MODE"

# 检测 GitHub Actions 环境（兼容现有日志逻辑）
if [ "$GITHUB_ACTIONS" = "true" ]; then
    export GITHUB_ACTIONS=true
fi

# 标记容器环境
export CONTAINER_ENV=true

# 检查必需环境变量
if [ -z "$CHECKIN_USERNAME" ] || [ -z "$CHECKIN_PASSWORD" ]; then
    echo "❌ 错误：必须设置 CHECKIN_USERNAME 和 CHECKIN_PASSWORD 环境变量"
    exit 1
fi

# 生成 config.json（兼容现有代码）
cat > config.json << EOF
{
  "username": "$CHECKIN_USERNAME",
  "password": "$CHECKIN_PASSWORD",
  "wxpusher_app_token": "${WXPUSHER_APP_TOKEN:-}",
  "wxpusher_uid": "${WXPUSHER_UID:-}"
}
EOF

# 显示配置信息
echo "📋 环境变量检查："
echo "  用户名: ${CHECKIN_USERNAME:0:3}***"
WXPUSHER_STATUS=$([ -n "$WXPUSHER_APP_TOKEN" ] && echo "已配置" || echo "未配置")
echo "  WxPusher: $WXPUSHER_STATUS"

# 显示当前时间
echo "⏰ 当前时间: $(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S') (北京时间)"

case "$MODE" in
    scheduler)
        # 定时调度模式 - 容器持续运行，按北京时间准时执行任务
        echo "📅 启动定时调度器..."
        echo "💡 默认调度时间 (北京时间):"
        echo "   - 上班打卡: ${MORNING_CHECKIN_HOUR:-08}:${MORNING_CHECKIN_MINUTE:-00}"
        echo "   - 下班打卡: ${EVENING_CHECKIN_HOUR:-17}:${EVENING_CHECKIN_MINUTE:-00}"
        echo "   - 自动日报: ${DAILY_REPORT_HOUR:-17}:${DAILY_REPORT_MINUTE:-30}"
        exec python scheduler.py
        ;;
    once)
        # 一次性运行模式 - 运行指定脚本后退出
        echo "📅 一次性运行: python $SCRIPT"
        exec python "$SCRIPT"
        ;;
    checkin)
        # 快捷方式: 运行打卡
        echo "📅 运行打卡脚本"
        exec python auto_checkin.py
        ;;
    report)
        # 快捷方式: 运行日报
        echo "📅 运行日报脚本"
        exec python auto_daily_report.py
        ;;
    *)
        echo "❌ 未知模式: $MODE"
        echo "可用模式:"
        echo "  scheduler - 定时调度模式（推荐，容器持续运行）"
        echo "  once      - 一次性运行模式"
        echo "  checkin   - 快捷运行打卡"
        echo "  report    - 快捷运行日报"
        exit 1
        ;;
esac
