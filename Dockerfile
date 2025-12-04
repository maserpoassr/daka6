# 多阶段构建，确保镜像轻量
FROM python:3.11-slim AS builder

# 安装系统依赖（Playwright + ddddocr 需要）
RUN apt-get update && apt-get install -y \
    wget gnupg \
    libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    fonts-liberation libnspr4 libatk1.0-0 libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# 安装 Playwright 浏览器
RUN ~/.local/bin/playwright install chromium --with-deps

# 运行阶段：轻量镜像
FROM python:3.11-slim

# 复制系统依赖
RUN apt-get update && apt-get install -y \
    libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    fonts-liberation libnspr4 libatk1.0-0 libatspi2.0-0 \
    libatspi2.0-0 libxshmfence-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .

# 设置 PATH
ENV PATH=/root/.local/bin:$PATH
ENV PLAYWRIGHT_BROWSERS_PATH=/root/.local/share/ms-playwright

# 暴露端口（如果 Leaflow 需要）
EXPOSE 8080

# 入口脚本
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
