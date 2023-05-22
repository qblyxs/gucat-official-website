FROM python:3.11.3-alpine
# 维护者信息
LABEL maintainer="gucat@gucat.cn"
# 设置生产模式环境变量 
# ENV APP_ENV production
# pipy源设置
RUN pip config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple/
# 设置时区
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk --no-cache add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apk --no-cache del tzdata && \
    mkdir /app
# 设置工作目录
WORKDIR /app
# 拷贝数据
COPY Qexo /app
# 安装依赖
RUN pip install -r requirements.txt && \
    python3 manage.py makemigrations && \
    python3 manage.py migrate
# 暴露端口
EXPOSE 8000
# 启动django
ENTRYPOINT ["python3", "manage.py", "runserver", "0.0.0.0:8000", "--noreload"]