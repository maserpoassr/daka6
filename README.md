# 自动打卡与日报系统 (容器版)

基于 Playwright 的自动化脚本，支持容器内定时调度，解决外部平台调度不准确的问题。

## ✨ 功能特点

- **内置定时调度**：使用 APScheduler 在容器内按北京时间准时运行
- **防重复运行**：锁机制 + 每日记录，防止重复打卡
- **自动打卡**：每天定时自动登录并完成打卡
- **自动日报**：每天定时自动生成并提交日报（支持 AI 生成）
- **微信通知**：通过 WxPusher 推送任务结果

## 🚀 快速开始

### 运行模式

容器支持两种运行模式：

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `scheduler` | 定时调度模式（默认） | 容器持续运行，按北京时间准时执行 |
| `once` | 一次性运行模式 | 外部调度触发，运行后退出 |

### 推荐：定时调度模式

容器持续运行，内置调度器按北京时间准时执行任务，不依赖外部平台的调度。

```bash
docker run -d --name daka \
  -e CHECKIN_USERNAME=你的用户名 \
  -e CHECKIN_PASSWORD=你的密码 \
  -e WXPUSHER_APP_TOKEN=你的Token \
  -e WXPUSHER_UID=你的UID \
  ghcr.io/你的用户名/仓库名:latest scheduler
```

默认调度时间（北京时间）：
- 上班打卡：08:00
- 下班打卡：17:00
- 自动日报：17:30

### 自定义调度时间

通过环境变量自定义：

```bash
docker run -d --name daka \
  -e CHECKIN_USERNAME=你的用户名 \
  -e CHECKIN_PASSWORD=你的密码 \
  -e MORNING_CHECKIN_HOUR=7 \
  -e MORNING_CHECKIN_MINUTE=50 \
  -e EVENING_CHECKIN_HOUR=18 \
  -e EVENING_CHECKIN_MINUTE=0 \
  -e DAILY_REPORT_HOUR=18 \
  -e DAILY_REPORT_MINUTE=30 \
  ghcr.io/你的用户名/仓库名:latest scheduler
```

### 一次性运行模式

如果你仍想使用外部调度（如 Leaflow 的定时任务），可以使用一次性模式：

```bash
# 运行打卡
docker run --rm \
  -e CHECKIN_USERNAME=你的用户名 \
  -e CHECKIN_PASSWORD=你的密码 \
  ghcr.io/你的用户名/仓库名:latest once auto_checkin.py

# 运行日报
docker run --rm \
  -e CHECKIN_USERNAME=你的用户名 \
  -e CHECKIN_PASSWORD=你的密码 \
  ghcr.io/你的用户名/仓库名:latest once auto_daily_report.py

# 快捷方式
docker run --rm -e ... ghcr.io/.../...:latest checkin
docker run --rm -e ... ghcr.io/.../...:latest report
```

## 🐳 Leaflow 部署

### 方案一：定时调度模式（推荐）

创建一个持续运行的容器：

| 配置项 | 值 |
|--------|-----|
| 镜像地址 | `ghcr.io/你的用户名/仓库名:latest` |
| CPU | 1核 |
| 内存 | 2GB |
| 命令参数 | `scheduler` |
| 环境变量 | 见下表 |

容器会持续运行，内部调度器按北京时间准时执行任务。

### 方案二：一次性模式

如果 Leaflow 不支持持续运行容器，使用一次性模式：

| 配置项 | 值 |
|--------|-----|
| 命令参数 | `checkin` 或 `report` |
| 调度 | 由 Leaflow 平台设置 |

## 📋 环境变量

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
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

## 🔧 防重复运行机制

容器内置防重复运行机制：

1. **文件锁**：同一任务同时只能运行一个实例
2. **每日记录**：成功执行后记录，当天不再重复执行
3. **状态检查**：日报脚本会检查是否已提交

## 📝 文件说明

- `scheduler.py`: 定时调度器（核心）
- `auto_checkin.py`: 自动打卡脚本
- `auto_daily_report.py`: 自动日报脚本
- `entrypoint.sh`: 容器入口脚本

## ⚠️ 免责声明

本脚本仅供学习交流使用，请遵守相关规定。
