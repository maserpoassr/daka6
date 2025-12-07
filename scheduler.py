"""
定时调度器 - 按北京时间准时运行打卡和日报任务
使用 APScheduler 实现容器内定时调度，避免依赖外部平台的不准确调度
"""

import asyncio
import os
import sys
import signal
import fcntl
from datetime import datetime, timezone, timedelta
from pathlib import Path
import logging

# 北京时区 (UTC+8)
BEIJING_TZ = timezone(timedelta(hours=8))

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# 锁文件目录
LOCK_DIR = Path('/tmp/daka_locks')
LOCK_DIR.mkdir(exist_ok=True)

# 今日执行记录文件
DAILY_RECORD_FILE = LOCK_DIR / 'daily_record.txt'


def get_today_date() -> str:
    """获取今天的日期（北京时间）"""
    return datetime.now(BEIJING_TZ).strftime('%Y-%m-%d')


def get_lock_file(task_name: str) -> Path:
    """获取任务锁文件路径"""
    return LOCK_DIR / f'{task_name}.lock'


def acquire_lock(task_name: str) -> bool:
    """
    获取任务锁，防止重复运行
    
    Returns:
        True: 成功获取锁, False: 锁已被占用
    """
    lock_file = get_lock_file(task_name)
    try:
        fd = os.open(str(lock_file), os.O_CREAT | os.O_RDWR)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # 写入 PID
        os.write(fd, str(os.getpid()).encode())
        os.fsync(fd)
        logger.info(f"✓ 获取锁成功: {task_name}")
        return True
    except (IOError, OSError):
        logger.warning(f"⚠️ 任务 {task_name} 正在运行中，跳过本次执行")
        return False


def release_lock(task_name: str):
    """释放任务锁"""
    lock_file = get_lock_file(task_name)
    try:
        lock_file.unlink(missing_ok=True)
        logger.info(f"✓ 释放锁: {task_name}")
    except Exception as e:
        logger.warning(f"释放锁失败: {e}")


def has_run_today(task_name: str) -> bool:
    """
    检查任务今天是否已经成功运行过
    
    Returns:
        True: 今天已运行, False: 今天未运行
    """
    today = get_today_date()
    record_key = f"{today}:{task_name}"
    
    try:
        if DAILY_RECORD_FILE.exists():
            content = DAILY_RECORD_FILE.read_text()
            if record_key in content:
                logger.info(f"✓ 任务 {task_name} 今天已成功运行，跳过")
                return True
    except Exception as e:
        logger.warning(f"读取执行记录失败: {e}")
    
    return False


def mark_run_today(task_name: str):
    """标记任务今天已成功运行"""
    today = get_today_date()
    record_key = f"{today}:{task_name}"
    
    try:
        # 清理旧记录（只保留今天的）
        lines = []
        if DAILY_RECORD_FILE.exists():
            lines = [l for l in DAILY_RECORD_FILE.read_text().splitlines() 
                    if l.startswith(today)]
        
        if record_key not in lines:
            lines.append(record_key)
        
        DAILY_RECORD_FILE.write_text('\n'.join(lines))
        logger.info(f"✓ 已标记任务 {task_name} 今天完成")
    except Exception as e:
        logger.warning(f"写入执行记录失败: {e}")


async def run_checkin_task(task_type: str):
    """
    运行打卡任务（带防重复机制）
    
    Args:
        task_type: 'morning' (上班打卡) 或 'evening' (下班打卡)
    """
    task_name = f"checkin_{task_type}"
    
    # 检查今天是否已运行
    if has_run_today(task_name):
        return
    
    # 获取锁
    if not acquire_lock(task_name):
        return
    
    try:
        now = datetime.now(BEIJING_TZ)
        logger.info(f"========== 开始{task_type}打卡 ==========")
        logger.info(f"时间: {now.strftime('%Y-%m-%d %H:%M:%S')} (北京时间)")
        
        # 动态导入并运行打卡脚本
        from auto_checkin import AutoCheckin, send_notification, main as checkin_main
        
        # 直接调用 main 函数
        await checkin_main()
        
        # 标记今天已完成
        mark_run_today(task_name)
        
    except Exception as e:
        logger.error(f"打卡任务出错: {e}")
        import traceback
        logger.error(traceback.format_exc())
    finally:
        release_lock(task_name)


async def run_daily_report_task():
    """运行日报任务（带防重复机制）"""
    task_name = "daily_report"
    
    # 检查今天是否已运行
    if has_run_today(task_name):
        return
    
    # 获取锁
    if not acquire_lock(task_name):
        return
    
    try:
        now = datetime.now(BEIJING_TZ)
        logger.info(f"========== 开始提交日报 ==========")
        logger.info(f"时间: {now.strftime('%Y-%m-%d %H:%M:%S')} (北京时间)")
        
        # 动态导入并运行日报脚本
        from auto_daily_report import main as report_main
        
        await report_main()
        
        # 标记今天已完成
        mark_run_today(task_name)
        
    except Exception as e:
        logger.error(f"日报任务出错: {e}")
        import traceback
        logger.error(traceback.format_exc())
    finally:
        release_lock(task_name)


def run_async_task(coro_func, *args):
    """在新的事件循环中运行异步任务"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(coro_func(*args))
    finally:
        loop.close()


def start_scheduler():
    """启动定时调度器"""
    try:
        from apscheduler.schedulers.blocking import BlockingScheduler
        from apscheduler.triggers.cron import CronTrigger
    except ImportError:
        logger.error("请安装 apscheduler: pip install apscheduler")
        sys.exit(1)
    
    scheduler = BlockingScheduler(timezone='Asia/Shanghai')
    
    # 检查是否启用启动时立即运行（用于测试）
    run_on_startup = os.getenv('RUN_ON_STARTUP', 'false').lower() == 'true'
    
    # 从环境变量读取调度时间（可自定义）
    morning_checkin_hour = int(os.getenv('MORNING_CHECKIN_HOUR', '8'))
    morning_checkin_minute = int(os.getenv('MORNING_CHECKIN_MINUTE', '0'))
    evening_checkin_hour = int(os.getenv('EVENING_CHECKIN_HOUR', '17'))
    evening_checkin_minute = int(os.getenv('EVENING_CHECKIN_MINUTE', '0'))
    daily_report_hour = int(os.getenv('DAILY_REPORT_HOUR', '17'))
    daily_report_minute = int(os.getenv('DAILY_REPORT_MINUTE', '30'))
    
    # 上班打卡 - 默认北京时间 8:00
    scheduler.add_job(
        run_async_task,
        CronTrigger(hour=morning_checkin_hour, minute=morning_checkin_minute),
        args=[run_checkin_task, 'morning'],
        id='morning_checkin',
        name='上班打卡',
        misfire_grace_time=300  # 5分钟内的延迟仍然执行
    )
    
    # 下班打卡 - 默认北京时间 17:00
    scheduler.add_job(
        run_async_task,
        CronTrigger(hour=evening_checkin_hour, minute=evening_checkin_minute),
        args=[run_checkin_task, 'evening'],
        id='evening_checkin',
        name='下班打卡',
        misfire_grace_time=300
    )
    
    # 日报 - 默认北京时间 17:30
    scheduler.add_job(
        run_async_task,
        CronTrigger(hour=daily_report_hour, minute=daily_report_minute),
        args=[run_daily_report_task],
        id='daily_report',
        name='自动日报',
        misfire_grace_time=300
    )
    
    # 打印调度信息
    now = datetime.now(BEIJING_TZ)
    logger.info("=" * 50)
    logger.info("🚀 定时调度器已启动")
    logger.info(f"当前时间: {now.strftime('%Y-%m-%d %H:%M:%S')} (北京时间)")
    logger.info("=" * 50)
    logger.info("📅 调度任务:")
    logger.info(f"  - 上班打卡: 每天 {morning_checkin_hour:02d}:{morning_checkin_minute:02d}")
    logger.info(f"  - 下班打卡: 每天 {evening_checkin_hour:02d}:{evening_checkin_minute:02d}")
    logger.info(f"  - 自动日报: 每天 {daily_report_hour:02d}:{daily_report_minute:02d}")
    logger.info("=" * 50)
    logger.info("💡 提示: 可通过环境变量自定义时间:")
    logger.info("  MORNING_CHECKIN_HOUR, MORNING_CHECKIN_MINUTE")
    logger.info("  EVENING_CHECKIN_HOUR, EVENING_CHECKIN_MINUTE")
    logger.info("  DAILY_REPORT_HOUR, DAILY_REPORT_MINUTE")
    logger.info("  RUN_ON_STARTUP=true (启动时立即运行一次，用于测试)")
    logger.info("=" * 50)
    
    # 启动时立即运行一次（用于测试）
    if run_on_startup:
        logger.info("🔄 启动时立即运行一次...")
        current_hour = now.hour
        
        # 根据当前时间判断运行哪个任务
        if 6 <= current_hour < 17:
            logger.info("→ 运行上班打卡")
            run_async_task(run_checkin_task, 'morning')
        else:
            logger.info("→ 运行下班打卡")
            run_async_task(run_checkin_task, 'evening')
        
        logger.info("→ 运行日报")
        run_async_task(run_daily_report_task)
        logger.info("✅ 启动时任务已完成")
    
    # 优雅退出处理
    def signal_handler(signum, frame):
        logger.info("收到退出信号，正在关闭调度器...")
        scheduler.shutdown(wait=False)
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        logger.info("调度器已停止")


if __name__ == '__main__':
    try:
        logger.info("=" * 50)
        logger.info("🚀 容器启动 - 定时调度器模式")
        logger.info("=" * 50)
        start_scheduler()
    except Exception as e:
        logger.error(f"❌ 调度器启动失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        sys.exit(1)
