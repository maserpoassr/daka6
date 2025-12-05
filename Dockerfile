FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai

# 设置容器时区为北京时间
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo Asia/Shanghai > /etc/timezone

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    wget gnupg curl \
    libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    fonts-liberation libnspr4 libatk1.0-0 libatspi2.0-0 \
    libxshmfence1 libgtk-3-0 libx11-xcb1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制文件
COPY requirements.txt .
COPY *.py ./
COPY entrypoint.sh ./

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 安装 Playwright
RUN python -m playwright install chromium

# 修复换行符并设置权限
RUN dos2unix entrypoint.sh 2>/dev/null || sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh

ENTRYPOINT ["bash", "./entrypoint.sh"]
