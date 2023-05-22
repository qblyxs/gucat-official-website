# gucat-official-website项目dev开发分支
# 本分支为开发测试新功能使用变化较大,请勿直接使用
# GUCAT 官网

这是一个基于 Node 的 Hexo 静态网站官网，主要用于分享 K8s DevOps 相关的知识和经验，包括 Jenkins、ArgoCD、Twikoo、Memos 等各种服务，并提供相关代码和配置清单。

## 构建

本项目提供了 K8s 集群相关的配置清单和 Jenkinsfile、Dockerfile 等信息，您可以通过以下方式部署本项目：

1. 克隆本仓库到您的本地：`git clone https://github.com/qblyxs/gucat-official-website.git`
2. 根据官网教程或者仓库说明进行相关配置
3. 运行 `jenkins` 流水线调用`kubernetes` 集群`API` 动态创建所流水线需要的全部`pod` 
4. 使用 `Jenkinsfile` 和 `Dockerfile` 构建 `Docker` 镜像 
5. 该过程会通过流水线里的`kaniko` 镜像构建`docker` 镜像 ,并推送到`hub仓库中`

## 部署

1. 可直接使用`docker run --name gucat -d -p 80:4000 qblyxs/gucat-web:latest` 运行本站镜像
2. 可直接跳过构建过程,直接使用`docker pull qblyxs/qblyxs/gucat-web:latest` 拉取本站制作好的镜像
3. 或者将本仓库配置到`argoCD` 中,并通过`argoCD` 动态创建`kubernetes` 资源,资源文档在`deploy` 目录下
4. 或者直接使用`kubectl apply -f deploy` 目录下的资源清单进行部署


注意，完整复现本项目需要一套`k8s`集群,集群需要集成`jenkins` 和 `argocd` 两个服务,并且需要配置`jenkins` 的`pipeline` 和`argoCD` 的`application` 两个流水线,同时完整复现本站还需要配置`twikoo` 等一系列微服务和云函数。

## 使用

本官网主要用于分享 K8s DevOps 相关知识和经验，您可以通过以下方式使用官网：

1. 访问官网网址：`https://gucat.vip/`
2. 在官网中阅读相关的文章，学习相关知识和经验
3. 通过博客评论系统 Twikoo 发表您的评论和想法
4. 相关平台网址: `https://jenkins.gucat.vip/` `https://argocd.gucat.vip/` `https://twikoo.gucat.vip/` `https://memos.gucat.vip/` `https://mirrors.gucat.vip/`


## 贡献者

本项目的贡献者包括：

- Fomalhaut🥝 (https://github.com/fomalhaut1998/hexo-theme-Fomalhaut.git) ,该作者提供的模板修改
- jerryc127 (https://github.com/jerryc127/hexo-theme-butterfly) ,该作者提供的主题模板

如果您想为本项目做出贡献，请发送邮件至 `gucat@gucat.cn`，我们将非常欢迎您的参与。

## 许可证

本项目采用 MIT 许可证进行许可，详情请参见 `LICENSE` 文件。

## 版本历史

本项目的版本历史如下：

- v1.0.0：内测阶段，包括基础网站框架和devops环境等配置与测试
- v1.0.1：公测阶段，包括网站和相关服务的测试和试发布
- v1.0.2：新增 Jenkins、ArgoCD、Twikoo、Memos 等服务的文章和资源清单
- v1.0.x: 修复一系列出现的BUG
- v1.1.0：发布第一个线上版本。

## 问题与反馈

如果您在使用本项目时遇到任何问题或有任何反馈，请发送邮件至 `gucat@gucat.cn`，我们将会及时处理并回复您。

## 参考资料

本项目使用以下框架和工具：

- kubernetes：一个容器编排引擎
- Hexo：一个基于 Node 的静态网站框架
- Jenkins：一个自动化构建工具
- ArgoCD：一个 K8s 的 GitOps 工具
- Twikoo：一个轻量的博客评论系统
- Memos：一个轻量的在线笔记系统
- Kaniko：一个轻量的 Docker 镜像构建工具
- container-structure-test：一个轻量的 Docker 镜像测试工具
- filebrowser：一个轻量的文件管理工具

我们在使用这些框架和工具时，参考了以下资料：

- 官方文档：https://hexo.io/docs/
- Jenkins 中文文档：https://www.jenkins.io/zh/doc/
- ArgoCD 官方文档：https://argoproj.github.io/argo-cd/
- Twikoo 官方文档：https://twikoo.js.org/

## 作者信息

本官网由 `孤猫`(qblyxs) 设计和开发，技术支持由 `孤猫`(qblyxs) 提供。

如需联系作者，请发送邮件至 `gucat@gucat.cn`。
或者通过以下方式联系作者：
微信：`qblyxs` (请注明来意)

## 附加说明

本 README.md 文档可以在 GitHub 仓库中进行编辑和更新，如有任何修改和更新，请联系贡献者进行审核和合并。
本仓库国内镜像同步地址：https://gitee.com/qblyxs/gucat-official-website.git
另外欢迎联系我进行项目开发和合作，谢谢！