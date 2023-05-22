---
title: 关于
date: 2022-08-10 16:05:11
type: about
---

{% note warning modern %}<b>非商免字体、网图</b>等资源未经授权仅限个人使用，不得用于商业用途。本站平时仅用于交流和学习，如涉及侵权请联系站长删除对应资源，谢谢！ —— 致版权方{% endnote %}

## 1.网站架构信息
<div class="about_page">

+ 部署 : 基于`kubernetes`的`devops自动化`部署
使用`githook`触发`jenkins`构建,`jenkins`调用`kubernetes`创建动态`pod`使用`kaniko`制作镜像,构建完成后由`argocd`自动部署到`kubernetes`集群,并进行`健康检查`
+ 服务器 : 腾讯云服务器 + 华为云服务器
腾讯云轻量应用服务器 + 华为云云服务器 + 腾讯云CVM服务器`混合架构`的kubernetes集群
+ 操作系统 : `OpenCloudOS 8.6` + `AlmaLinux 8.7` (Stone Smilodon)
+ 集群 : 3台master + 2台node 
+ 负载均衡 : 2个`nginx-ingress`控制器 + 3个`haproxy`服务 `动态分配流量`
+ 域名 : [www.gucat.vip](https://www.gucat.vip/)
本站主要使用[gucat.vip](https://gucat.vip/)提供对外服务,使用[gucat.cn](https://gucat.cn/)提供对内服务和`邮件服务`
+ 自动构建 : [jenkins](https://jenkins.gucat.vip/)
本站`jenkins`系统支持游客匿名访问,欢迎大家查看
+ 自动部署 : [argocd](https://argocd.gucat.vip/)
本站`argocd`系统暂不支持匿名访问,请见谅
+ 留言板 : [memos](https://memos.gucat.vip/)
memos微服务同样通过kubernetes部署,支持游客匿名访问,欢迎大家查看
+ 评论系统 : [twikoo](https://twikoo.gucat.vip/)
twikoo微服务同样通过kubernetes部署,且已配置腾讯云内容安全服务
+ 云存储 : [文件系统](https://mirrors.gucat.vip/)
自建文件存储系统,已经`开放注册`,欢迎大家使用

</div>

## 2.前端页面介绍
<div class="about_page">

+ 前端框架 : [Hexo](https://hexo.io/zh-cn/)
+ 前端主题 : [Butterfly 4.3.1](https://butterfly.js.org/)
+ 魔改作者 : [Fomalhaut🥝](https://www.fomal.cc/)
+ 主题源码 : [Github](https://github.com/fomalhaut1998/hexo-theme-Fomalhaut)
<br>
</div>

## 2.关于我
<div class="about_page">

+ 昵称 : 孤猫
+ 性别 ：♂
+ 生日 ：199X.03.xx
+ 地点 ：中国.四川.成都
+ 邮箱 ：qblyxs@qq.com | gucat@gucat.cn
+ 擅长 ：没有什么特别擅长的,只是对技术比较感兴趣,喜欢折腾
+ 兴趣 : 云原生 | DevOps | Kubernetes | Docker | Linux | Python | Golang | Vue | React | Threejs | 机器学习 | 人工智能 | 云计算 | 云存储 | 云数据库 | 云网络 | 云安全 |
+ 取得证书 : `腾讯云架构高级工程师`
{% image https://mirrors.gucat.vip/api/public/dl/14CAGQhl?inline=true, width=400px, alt=欢迎项目合作,证书全称打码处理了(*^▽^*) %}