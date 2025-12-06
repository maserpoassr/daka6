# 自动打卡与日报（容器版）

基于 Playwright 的自动化脚本，内置容器调度，适合直接推到 leaflow.net 运行。

## 功能
- 容器内 APScheduler 定时（北京时间），不依赖外部定时
- 文件锁 + 每日记录防重复
- 自动打卡 / 自动日报（支持一次性触发）
- WxPusher 结果通知

## 运行模式
| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `scheduler` | 默认；容器内持续调度 | 推荐，用于 Leaflow 长跑容器 |
| `once` | 单次运行指定脚本 | 外部平台定时触发 |
| `checkin` / `report` | 快捷单次打卡 / 日报 | 外部平台定时触发 |

## 快速使用
```bash
# 持续调度（推荐）
docker run -d --name daka \
  -e CHECKIN_USERNAME=你的用户名 \
  -e CHECKIN_PASSWORD=你的密码 \
  -e WXPUSHER_APP_TOKEN=你的Token \
  -e WXPUSHER_UID=你的UID \
  ghcr.io/你的用户名/仓库名:latest scheduler

# 自定义时间（北京时间）
docker run -d --name daka \
  -e CHECKIN_USERNAME=... \
  -e CHECKIN_PASSWORD=... \
  -e MORNING_CHECKIN_HOUR=7 -e MORNING_CHECKIN_MINUTE=50 \
  -e EVENING_CHECKIN_HOUR=18 -e EVENING_CHECKIN_MINUTE=0 \
  -e DAILY_REPORT_HOUR=18 -e DAILY_REPORT_MINUTE=30 \
  ghcr.io/你的用户名/仓库名:latest scheduler

# 外部定时（单次）
docker run --rm -e CHECKIN_USERNAME=... -e CHECKIN_PASSWORD=... \
  ghcr.io/你的用户名/仓库名:latest checkin
docker run --rm -e CHECKIN_USERNAME=... -e CHECKIN_PASSWORD=... \
  ghcr.io/你的用户名/仓库名:latest report
```

默认时间（北京时间）：
- 上班打卡 08:00
- 下班打卡 17:00
- 日报提交 17:30

## Leaflow 部署建议
- 调度容器：命令参数 `scheduler`，CPU 1C、内存 2GB；容器持续运行，由内置调度按北京时间触发。
- 外部定时：命令参数 `checkin` 或 `report`，由 Leaflow 的任务调度。

## 环境变量
| 变量 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `CHECKIN_USERNAME` | ✅ | - | 登录用户名 |
| `CHECKIN_PASSWORD` | ✅ | - | 登录密码 |
| `WXPUSHER_APP_TOKEN` | ❌ | - | WxPusher 应用 Token |
| `WXPUSHER_UID` | ❌ | - | WxPusher 用户 UID |
| `MORNING_CHECKIN_HOUR` | ❌ | 8 | 上班打卡小时 |
| `MORNING_CHECKIN_MINUTE` | ❌ | 0 | 上班打卡分钟 |
| `EVENING_CHECKIN_HOUR` | ❌ | 17 | 下班打卡小时 |
| `EVENING_CHECKIN_MINUTE` | ❌ | 0 | 下班打卡分钟 |
| `DAILY_REPORT_HOUR` | ❌ | 17 | 日报提交小时 |
| `DAILY_REPORT_MINUTE` | ❌ | 30 | 日报提交分钟 |
| `RUN_MODE` | ❌ | scheduler | 入口默认模式，可用 once/checkin/report |

## 文件
- `scheduler.py`：容器内定时调度
- `auto_checkin.py`：自动打卡
- `auto_daily_report.py`：自动日报
- `entrypoint.sh`：容器入口，生成 config.json 并按模式启动

## 免责声明
仅供学习交流，请遵守相关规定。
