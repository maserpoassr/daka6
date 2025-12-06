FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    PLAYWRIGHT_BROWSERS_PATH=0

# 设置容器时区为北京时间
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo Asia/Shanghai > /etc/timezone

# 安装系统依赖（无推荐包，减小镜像）
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg curl ca-certificates \
    libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    fonts-liberation libnspr4 libatk1.0-0 libatspi2.0-0 \
    libxshmfence1 libgtk-3-0 libx11-xcb1 \
    libgomp1 libglib2.0-0 libsm6 libxrender1 libxext6 libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先复制依赖清单便于缓存
COPY requirements.txt .

# 升级 pip 并安装 Python 依赖（使用国内镜像源）
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install -i https://pypi.tsinghua.edu.cn/simple --no-cache-dir -r requirements.txt || \
    pip install --no-cache-dir -r requirements.txt

# 安装 Playwright 运行时依赖与浏览器
RUN python -m playwright install-deps chromium && python -m playwright install chromium

# 复制项目文件
COPY *.py ./
COPY entrypoint.sh ./

# 默认使用定时调度模式
ENV RUN_MODE=scheduler

# 修复换行符并设置权限
RUN bash -c "sed -i 's/\\r$//' entrypoint.sh || true" && chmod +x entrypoint.sh

ENTRYPOINT ["bash", "./entrypoint.sh"]
