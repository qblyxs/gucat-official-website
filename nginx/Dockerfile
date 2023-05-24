FROM node:alpine
# 维护者信息
LABEL maintainer="gucat@gucat.cn"
# 设置时区
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk --no-cache add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apk --no-cache del tzdata
# 设置工作目录
WORKDIR /usr/share/nginx/html
# 拷贝数据
COPY ./blog/public/ /usr/share/nginx/html
# 暴露80端口
EXPOSE 80
# 挂载卷
VOLUME /usr/share/nginx/html
VOLUME /etc/nginx/conf.d
# 启动 nginx
CMD ["nginx", "-g", "daemon off;"]