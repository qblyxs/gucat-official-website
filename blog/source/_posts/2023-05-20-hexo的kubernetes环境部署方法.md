---
title: 基于kubernetes的hexo项目自动化部署
description: 在kubernetes集群中部署hexo项目的方法,并通过jenkins和argocd实现自动化构建和部署
mathjax: true
tags:
  - 应用部署
  - devops
  - kubernetes
categories:
  - deploy
abbrlink: 20230520d
sticky: 100
swiper_index: 100
date: 2023-05-20 10:19:03
---

## 说明
<!-- tab -->
1. 本文介绍在kubernetes集群中如何安装hexo的方法,并且通过jenkins集成kubernetes的api，调用kubernetes集群实现自动化构建docker镜像并推送到dockerhub，最后通过argocd实现自动化部署。达到kubernetes+jenkins+argocd+github+docker的devops自动化。
2. 本文的前置条件较多，需要有kubernetes集群，jenkins，argocd，dockerhub，github等基础知识，本文不做过多介绍。
3. 本方法实现难度较高，需要有一定的kubernetes基础，和一点开发能力。
4. 自用部署可以采取稍微简单一点的docker部署等方法，本文不做过多介绍。
<!-- endtab -->
## 1. hexo项目的相关文件与配置编写
### 1.1. dockerfile编写
```Dockerfile
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
# 暴露端口
EXPOSE 4000
# 启动hexo
ENTRYPOINT ["hexo", "server"]
```
### 1.2. jenkinsfile简单版流水线编写
<!-- tab -->
1. 这部分的配置较多,需要将github和gitee的认证信息配置到jenkins中，这里不做过多介绍。
2. 在kubernetes中构建镜像的方法比较多,如docker-in-docker/dind-rootless、Kubernetes IN Docker、Kaniko、BuildKit、Buildah、Img等架构，本文采用kaniko的方式进行构建。
3. kaniko的构建方式比较特殊，需要提前在kubernetes集群中创建secret，将dockerhub的认证信息存储到secret中，然后在jenkinsfile中调用secret进行认证，最后进行构建。
4. webhook的配置，我采用的是github的webhook通知jenkins，jenkins再调用kubernetes的api进行构建，这样的好处是可以在jenkins中进行更多的操作，比如构建前的检查，构建后的通知等。
5. 拉取的代码从gitee拉取，为什么不从github拉取呢？因为github在国内访问速度太慢了，gitee的速度还可以。所以我做了不同仓库的镜像同步，代码推送到gitee后，会自动同步到github，然后github通知jenkins有push事件，jenkins再调用kubernetes的api创建需要的临时pod进行构建。
6. 镜像构建完成后kaniko会自动推送到dockerhub。
7. 最后argocd会自动从hub仓库拉取镜像部署到kubernetes集群中。
8. argocd自动化需要准备好相关配置清单，这里不做过多介绍。
<!-- endtab -->

```groovy
// 定义全局变量
// def DOCKER_REGISTRY = ''
def nodeSelector = 'jenkins-slave=master'  // k8s-slave运行节点标签
def gitRepoUrl = 'https://gitee.com/qblyxs/gucat-official-website.git'  // git仓库地址
def branch = 'master'  // git分支
def gitCredentialsId = 'gitee-auth-qblyxs'  // git认证信息
def imageName = 'qblyxs/gucat-web'  // 镜像名称
// def imageTag = '1.0.${BUILD_NUMBER}'  // 镜像标签
def imageTag = '1.0.1'  // 镜像标签

// 注意事项
// 1. secretVolume.secretName.'kaniko-secret' 需要提前在k8s集群中创建 kubectl create secret -n devops-tools generic kaniko-secret --from-file=/path/config.json
// 2. config.json中的"auth"字段及认证信息需要base64加密后填入 例如: echo -n username:password | base64
// 3. jenkins-slave=master 需要提前在k8s集群中创建 kubectl label node k8s-node2 jenkins-slave=master

podTemplate(
    nodeSelector: "${nodeSelector}",
    containers: [
    // containerTemplate(name: 'node', image: 'node:20.1-alpine', command: 'sleep', args: '99d'),
    containerTemplate(name: 'kaniko', image: 'qblyxs/kaniko:v1.9.2-debug', command: 'sleep', args: '10d')],
    volumes: [
    secretVolume(secretName: 'kaniko-secret', mountPath: '/kaniko/.docker/')
    ]
    )     {
    node(POD_LABEL) {
        stage('拉取代码') {
            git branch: "${branch}", credentialsId: "${gitCredentialsId}", url: "${gitRepoUrl}"
        }
        // 打包构建过程已经集成到node容器中
        // stage('node项目打包构建') {
        //     container('node') {
        //         stage('Build a Node project') {
        //             sh 'node -v'
        //             sh 'npm config set registry https://registry.npmmirror.com'
        //             sh 'npm install -g hexo-cli'
        //             sh 'cd blog && npm install' 
        //             timeout(time:20, unit:'SECONDS') {
        //                 echo '等待程序包准备中...'}
        //             sh 'cd blog && hexo generate -f'
        //             sh 'ls ./blog/public'
        //         }
        //     }   
        // }
        stage('使用kaniko构建镜像并推送DockerHub') {     
            container('kaniko') {
                // 使用jenkins进行认证
                stage('Build a Container') {
                    // 等待镜像准备完成
                    timeout(time:10, unit:'SECONDS') {
                        echo '等待镜像准备中...'}
                    sh "ls /kaniko/.docker/"
                    sh "ls "
                    sh "/kaniko/executor --context=. --destination=${imageName}:${imageTag}"
                }
            }
        }
    }
}
```
<!-- endtab -->
1. 关于工作镜像的制作,可以使用node镜像进行制作,缺点是node镜像比较大,构建时间比较长。
2. 也可以使用nginx镜像进行制作,缺点是nginx配置稍微比较麻烦,需要自己准备`nginx.conf`配置文件,且坑比较多。
3. 如果使用node镜像制作那么hexo的构建流程需要放到node镜像中，因为node镜像运行hexo server需要很多的node依赖。
4. 如果使用nginx镜像制作那么hexo的构建流程可以直接在jenkins流水线中完成，因为nginx镜像只需要静态文件即可。
5. jenkins流水线中构建node镜像的方法我写到了注释部分，有兴趣的可以自己尝试一下。jenkins构建完成后生成public目录，然后将public目录复制到nginx镜像中即可。
6. 本文采用的node镜像制作工作镜像，所以我将hexo的源代码COPY到镜像中。
7. 这个实现起来比较灵活,也可以通过k8s的volume挂载的方式将源代码挂载到镜像中,这样就可以实现源代码和镜像分离,方便后续的维护。
8. 方法比较多,不一一列举,有兴趣的可以自己尝试一下。
<!-- endtab -->

### 1.3 完善好源代码
<!-- tabView -->
1. 关于hexo的源代码建议放到一个目录中,例如`blog`目录。仓库根目录下只放一些必要的文件,例如`Dockerfile`、`Jenkinsfile`、`nginx.conf`等关键文件。
2. 将kubernetes部署的配置清单放到专门的`deploy`目录中,方便后续的维护和argocd的读取。
<!-- endtab -->
### 1.4 部署文件准备
#### 1.4.1 namespace
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: gucat
```

#### 1.4.2 deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gucat-web-deployment
  namespace: gucat
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gucat-web
  template:
    metadata:
      labels:
        app: gucat-web
    spec:
      nodeSelector:
        memos: enable
      containers:
      - name: gucat-web
        image: qblyxs/gucat-web:1.0.1
        imagePullPolicy: Always
        ports:
        - containerPort: 4000
---
```
#### 1.4.3 service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: gucat-web-service
  namespace: gucat
spec:
  type: ClusterIP
  selector:
    app: gucat-web
  ports:
    - name: http
      port: 4000
      targetPort: 4000
```
#### 1.4.4 ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gucat.vip
  namespace: gucat
spec:
  ingressClassName: nginx
  rules:
    - host: www.gucat.vip
      http:
        paths:
          - backend:
              service:
                name: gucat-web-service
                port:
                  number: 4000
            path: /
            pathType: Prefix
    - host: gucat.vip
      http:
        paths:
          - backend:
              service:
                name: gucat-web-service
                port:
                  number: 4000
            path: /
            pathType: Prefix
```
{% note success flat %} 🎉🎉🎉至此,我们的部署文件已经准备好了,接下来我们就可以推送仓库进行构建部署了。{% endnote %}

## 2. 推送仓库进行构建部署
### 2.1 推送仓库
<!-- tabView -->
1. 将我们的源代码推送到仓库中,例如我这里使用的是`gitee`仓库,仓库地址为`https://gitee.com/qblyxs/gucat-official-website.git`。
2. 在gitee设置中设置好`仓库镜像管理`,将代码自动同步到`github`仓库中,这样就可以实现`github`和`gitee`的代码同步。
3. 在`github`仓库中设置好`webhook`,代码自动同步后通知到`jenkins`。
<!-- endtab -->
### 2.2 构建部署
<!-- tabView -->
1. 在`jenkins`中新建一个`pipeline`流水线项目,这里我使用的是`多分支流水线`。将`github`仓库的地址填写到`源码管理`中。
2. `pipeline`脚本中配置了`gitee`的认证信息,这个信息需要提前在`jenkins凭据`中设置好。
<!-- endtab -->

## 3. argocd配置项目
### 3.1 argocd配置项目
<!-- tabView -->
1. 在`argocd`中新建一个`application`应用,将`github`仓库的地址填写到`源码管理`中。也可以填写`gitee`仓库的地址,因为`github`和`gitee`的代码是同步的。
2. `SYNC POLICY`选择`Automatic`自动同步,这样代码更新后会自动同步到`argocd`中。
3. `DESTINATION`中设置`Cluster URL`为`https://kubernetes.default.svc`。当然也可以部署到外部的`k8s`集群中,只需要将`Cluster URL`设置为外部集群的`api-server`地址并配置好`token`即可。`Namespace`不用设置,因为我们`deploy`清单中已经编写好了。
4. `PROJECT`中设置`PROJECT`为`default`。`PROJECT`是`argocd`中的一个概念,可以理解为`argocd`中的一个项目,可以将多个`application`应用放到一个`PROJECT`中。
5. `SYNC OPTIONS`中可以设置`Prune Resources`为`true`。这样当我们删除`application`应用时,`argocd`会自动删除`k8s`集群中的资源。
6. 当然完成前三个步骤后,就可以了,其他的可以根据自己的需求进行设置。
<!-- endtab -->

## 4. 最后展示下我的流水线
{% image https://mirrors.gucat.vip/api/public/dl/Rkcdr-Y4/job/j2.png?inline=true, width=600px, alt=jenkins负责制作hexo的镜像 %}
{% image https://mirrors.gucat.vip/api/public/dl/Rkcdr-Y4/job/a1.png?inline=true, width=600px, alt=argocd负责将服务部署到kubernetes集群中,并实时监控服务健康状态 %}