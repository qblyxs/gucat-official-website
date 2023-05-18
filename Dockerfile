FROM node:alpine
# 维护者信息
LABEL maintainer="gucat@gucat.cn"
# 设置生产模式环境变量
ENV NODE_ENV=production
# npm源设置
RUN npm config set registry https://registry.npmmirror.com 
# 设置时区
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk --no-cache add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    apk --no-cache del tzdata && \
    mkdir /blog
# 安装hexo-cli
RUN npm install hexo-cli -g
# 拷贝数据
COPY ./blog /blog
# 安装依赖
RUN cd /blog && \
    npm install --production
# 设置工作目录
WORKDIR /blog
# 挂载卷
VOLUME /blog/source
# 暴露端口
EXPOSE 4000
# 启动hexo
ENTRYPOINT ["hexo", "server"]