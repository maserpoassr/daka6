# 单阶段构建，确保 Playwright 浏览器正确安装
FROM python:3.11-slim

# 设置环境变量
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# 安装系统依赖（Playwright + ddddocr 需要）
RUN apt-get update && apt-get install -y \
    wget gnupg curl \
    libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    fonts-liberation libnspr4 libatk1.0-0 libatspi2.0-0 \
    libxshmfence1 libgtk-3-0 libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 安装 Playwright 浏览器
RUN playwright install chromium --with-deps

# 复制应用文件
COPY *.py ./
COPY entrypoint.sh ./

# 设置入口脚本权限（解决 Windows 换行符问题）
RUN sed -i 's/\r$//' entrypoint.sh && chmod +x entrypoint.sh

# 暴露端口
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]
