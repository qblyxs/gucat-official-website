---
title: kubernetes（k8s）安装
description: 本文介绍使用kubeadm进行安装kubernetes（k8s）的方法
mathjax: true
tags:
  - kubernetes
  - 集群搭建
categories:
  - kubernetes
abbrlink: 20230519a
sticky: 80
swiper_index: 80
date: 2023-05-19 18:19:03
updated: 2023-05-19 22:00:00
---

## 说明
<!-- tab 渲染演示 -->
1. 本文以 CentOS 7.9、k8s 1.27.1为例
2. 本文固定了 k8s 的版本，防止不同版本存在差异，当你了解了某一版本的安装与使用，自己就可以尝试其他版本的安装了
3. 由于 k8s 1.24 及之后的版本使用的是 containerd，之前的版本是 docker，故此文使用containerd进行安装演示。
<!-- endtab -->

|          | master节点 | node节点 |
| -------- | -------- | ---- |
| 主机名 | k8s-master | k8s-node |
| IP | 192.168.56.20 | 192.168.56.21 |

## 1.所有节点进行安装准备
{% note warning flat %}本阶段命令需要在所有节点执行{% endnote %}
### 1.1安装所需工具
```shell
sudo yum -y install vim
sudo yum -y install wget
```
### 1.2将主机名指向本机IP
{% note info flat %} 主机名只能包含：字母、数字、-（横杠）、.（点）{% endnote %}
#### 1.2.1  获取主机名
```shell
hostname
```
#### 1.2.2  修改主机名
```shell
hostnamectl set-hostname k8s-master
```
#### 1.2.3  修改hosts文件
```shell
vim /etc/hosts
```
{% note info flat %} 在最后一行添加host对应关系,根据自己host主机名和IP进行添加 {% endnote %}
```shell
# 按如下格式添加
k8s-master 192.168.56.20
k8s-node 192.168.56.21
```
### 1.3安装并配置 ntpdate，同步时间
{% note info flat %} 云服务器默认已经安装了ntpdate跳过此步骤，如果是自己的服务器或主机，需要自己安装 {% endnote %}
```shell
sudo yum -y install ntpdate
sudo ntpdate ntp1.aliyun.com
sudo systemctl status ntpdate
sudo systemctl start ntpdate
sudo systemctl status ntpdate
sudo systemctl enable ntpdate
```
### 1.4安装并配置 bash-completion，添加命令自动补充
```shell
sudo yum -y install bash-completion
source /etc/profile
```
### 1.5关闭防火墙、或者开通指定端口
```shell
sudo systemctl stop firewalld.service 
sudo systemctl disable firewalld.service
```
{% note info flat %}
以下是开通指定端口的方法，如果执行了上面关闭命令，可以跳过此步骤
IP地址根据自己的实际情况注意修改成自己的
{% endnote %}
```shell
# 控制面节点master
firewall-cmd --zone=public --add-port=6443/tcp --permanent # Kubernetes API server	所有
firewall-cmd --zone=public --add-port=2379/tcp --permanent # etcd server client API	kube-apiserver, etcd
firewall-cmd --zone=public --add-port=2380/tcp --permanent # etcd server client API	kube-apiserver, etcd
firewall-cmd --zone=public --add-port=10250/tcp --permanent # Kubelet API	自身, 控制面
firewall-cmd --zone=public --add-port=10259/tcp --permanent # kube-scheduler	自身
firewall-cmd --zone=public --add-port=10257/tcp --permanent # kube-controller-manager	自身
firewall-cmd --zone=trusted --add-source=192.168.56.20 --permanent # 信任集群中各个节点的IP
firewall-cmd --zone=trusted --add-source=192.168.56.21 --permanent # 信任集群中各个节点的IP
firewall-cmd --add-masquerade --permanent # 端口转发
firewall-cmd --reload
firewall-cmd --list-all
firewall-cmd --list-all --zone=trusted

# 工作节点node
firewall-cmd --zone=public --add-port=10250/tcp --permanent # Kubelet API	自身, 控制面
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent # NodePort Services†	所有
firewall-cmd --zone=trusted --add-source=192.168.56.20 --permanent # 信任集群中各个节点的IP
firewall-cmd --zone=trusted --add-source=192.168.56.21 --permanent # 信任集群中各个节点的IP
firewall-cmd --add-masquerade --permanent # 端口转发
firewall-cmd --reload
firewall-cmd --list-all
firewall-cmd --list-all --zone=trusted
```

### 1.6关闭swap交换空间
```shell
free -h
sudo swapoff -a
sudo sed -i 's/.*swap.*/#&/' /etc/fstab
free -h
```

### 1.7关闭selinux
```shell
getenforce
cat /etc/selinux/config
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
cat /etc/selinux/config
```
### 1.8安装 Containerd、Docker
{% note info flat %}
Docker 不是必须的，k8s 1.24.0 开始使用 Containerd 替代 Docker,但还是推荐安装 Docker，原因：在k8s中构建Docker镜像时使用
/etc/containerd/config.toml 中的 SystemdCgroup = true 的优先级高于 /etc/docker/daemon.json 中的 cgroupdriver
{% endnote %}
```shell
# https://docs.docker.com/engine/install/centos/
# 经过测试，可不安装 docker 也可使 k8s 正常运行
# 只需要不安装 docker-ce、docker-ce-cli、docker-compose-plugin 即可

sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine containerd* # 卸载旧版本
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 # 安装必要依赖
# sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo #官方源
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo # 阿里云源 国内推荐使用阿里源
yum -y install docker-ce
# yum --showduplicates list docker-ce
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo yum install -y containerd

# 启动 docker 时，会启动 containerd
# sudo systemctl status containerd.service
sudo systemctl stop containerd.service

sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
sudo containerd config default > $HOME/config.toml
sudo cp $HOME/config.toml /etc/containerd/config.toml
# 修改 /etc/containerd/config.toml 文件后，要将 docker、containerd 停止后，再启动
sudo sed -i "s#registry.k8s.io/pause#registry.cn-hangzhou.aliyuncs.com/google_containers/pause#g" /etc/containerd/config.toml
# https://kubernetes.io/zh-cn/docs/setup/production-environment/container-runtimes/#containerd-systemd
# 确保 /etc/containerd/config.toml 中的 disabled_plugins 内不存在 cri
sudo sed -i "s#SystemdCgroup = false#SystemdCgroup = true#g" /etc/containerd/config.toml

# containerd 忽略证书验证的配置
#      [plugins."io.containerd.grpc.v1.cri".registry.configs]
#        [plugins."io.containerd.grpc.v1.cri".registry.configs."192.168.0.12:8001".tls]
#          insecure_skip_verify = true


sudo systemctl enable --now containerd.service
# sudo systemctl status containerd.service

# sudo systemctl status docker.service
sudo systemctl start docker.service
# sudo systemctl status docker.service
sudo systemctl enable docker.service
sudo systemctl enable docker.socket
sudo systemctl list-unit-files | grep docker

sudo mkdir -p /etc/docker

# 配置阿里云镜像加速器
# 腾讯云请使用该地址"https://mirror.ccs.tencentyun.com"
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://hnkfbj7x.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo docker info

sudo systemctl status docker.service
sudo systemctl status containerd.service
```
### 1.9添加阿里云 k8s 镜像仓库
```shell
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
# 是否开启本仓库
enabled=1
# 是否检查 gpg 签名文件
gpgcheck=0
# 是否检查 gpg 签名文件
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg

EOF
```
### 1.10配置网桥
```shell
# 设置所需的 sysctl 参数，参数在重新启动后保持不变
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1

EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system
```

### 1.11安装 kubeadm、kubelet 和 kubectl
```shell
# 如果你看到有人说 node 节点不需要安装 kubectl，其实这种说法是错的，kubectl 会被当做依赖安装，如果安装过程没有指定 kubectl 的版本，则会安装最新版的 kubectl，可能会导致程序运行异常

# yum --showduplicates list kubelet --nogpgcheck
# yum --showduplicates list kubeadm --nogpgcheck
# yum --showduplicates list kubectl --nogpgcheck

# 2023-02-07，经过测试，版本号：1.24.0，同样适用于本文章
# sudo yum install -y kubelet-1.24.0-0 kubeadm-1.24.0-0 kubectl-1.24.0-0 --disableexcludes=kubernetes --nogpgcheck

# sudo yum install -y kubelet-1.25.3-0 kubeadm-1.25.3-0 kubectl-1.25.3-0 --disableexcludes=kubernetes --nogpgcheck

# 2022-11-18，经过测试，版本号：1.25.4，同样适用于本文章
# sudo yum install -y kubelet-1.25.4-0 kubeadm-1.25.4-0 kubectl-1.25.4-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-02-07，经过测试，版本号：1.25.5，同样适用于本文章
# sudo yum install -y kubelet-1.25.5-0 kubeadm-1.25.5-0 kubectl-1.25.5-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-02-07，经过测试，版本号：1.25.6，同样适用于本文章
# sudo yum install -y kubelet-1.25.6-0 kubeadm-1.25.6-0 kubectl-1.25.6-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-02-07，经过测试，版本号：1.26.0，同样适用于本文章
# sudo yum install -y kubelet-1.26.0-0 kubeadm-1.26.0-0 kubectl-1.26.0-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-02-07，经过测试，版本号：1.26.1，同样适用于本文章
# sudo yum install -y kubelet-1.26.1-0 kubeadm-1.26.1-0 kubectl-1.26.1-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-03-02，经过测试，版本号：1.26.2，同样适用于本文章
# sudo yum install -y kubelet-1.26.2-0 kubeadm-1.26.2-0 kubectl-1.26.2-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-03-21，经过测试，版本号：1.26.3，同样适用于本文章
# sudo yum install -y kubelet-1.26.3-0 kubeadm-1.26.3-0 kubectl-1.26.3-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-04-13，经过测试，版本号：1.27.0，同样适用于本文章
# sudo yum install -y kubelet-1.27.0-0 kubeadm-1.27.0-0 kubectl-1.27.0-0 --disableexcludes=kubernetes --nogpgcheck

# 2023-04-19，经过测试，版本号：1.27.1，同样适用于本文章
# sudo yum install -y kubelet-1.27.1-0 kubeadm-1.27.1-0 kubectl-1.27.1-0 --disableexcludes=kubernetes --nogpgcheck

# 安装最新版，生产时不建议
# sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes --nogpgcheck

systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl enable kubelet
```

### 1.12查看 kubelet 状态
```shell
# k8s 未初始化时，kubelet 可能无法启动，这是正常现象
systemctl status kubelet
```
{% note danger modern %}
以上命令1.1至1.11需要在所有节点执行，并确保没有错误与警告
以上命令1.1至1.11需要在所有节点执行，并确保没有错误与警告
{% endnote %}

## 2.初始化控制节点
### 2.1初始化控制节点
{% note warning flat %} 此部分命令只需在一个控制节点执行 {% endnote %}
```shell
kubeadm init --image-repository=registry.aliyuncs.com/google_containers
# kubeadm init --image-repository registry.aliyuncs.com/google_containers \
# --kubernetes-version=1.27.1 \
# --pod-network-cidr=10.244.0.0/16 \
# --control-plane-endpoint=192.168.56.20 \
# --apiserver-advertise-address=192.168.56.20

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 或者在环境变量中添加：export KUBECONFIG=/etc/kubernetes/admin.conf
# 添加完环境变量后，刷新环境变量：source /etc/profile

kubectl cluster-info

# 初始化失败后，可进行重置，重置命令：kubeadm reset

# 执行成功后，会出现类似下列内容：
# kubeadm join 192.168.56.20:6443 --token f9lvrz.59mykzssqw6vjh32 \
# --discovery-token-ca-cert-hash sha256:4e23156e2f71c5df52dfd2b9b198cce5db27c47707564684ea74986836900107 	

#
# kubeadm token create --print-join-command
```
### 2.2kubeadm初始化集群参数说明
```shell
# 下面是kubeadm的一些参数说明 
# --image-repository 指定镜像仓库地址，如果不指定，则默认从k8s.gcr.io下载镜像，国内无法访问
# --kubernetes-version 指定k8s版本，默认为最新版本
# --pod-network-cidr 指定pod网络地址段，flannel默认为10.244.0.0/16，calico默认为192.168.0.0/16
# --control-plane-endpoint 指定apiserver的访问地址，如果不指定，则默认为内网ip
# --apiserver-advertise-address 指定apiserver的访问地址，如果不指定，则默认为内网ip
# --ignore-preflight-errors 指定初始化时忽略的错误，例如：--ignore-preflight-errors=NumCPU
# --upload-certs 上传证书到etcd，如果不指定，则默认不上传
# --dry-run 执行初始化前的检查，如果不指定，则默认不执行检查
# --config 指定配置文件，如果不指定，则默认从/etc/kubernetes/kubeadm.conf加载配置
```
### 2.3初始化控制节点失败的解决办法
{% note danger modern %} !!!正常情况不要执行，除非初始化失败 {% endnote %}
```shell
# 1.如果初始化失败，可以通过下面的命令重置集群
kubeadm reset
```
## 3.初始化node节点
### 3.1初始化node节点
{% note warning flat %} 此部分命令需要在所有node节点执行 {% endnote %}
```shell
# 到master节点复制执行成功后，出现的类似下列内容：
# kubeadm join 192.168.56.20:6443 --token f9lvrz.59mykzssqw6vjh32 \
# --discovery-token-ca-cert-hash sha256:4e23156e2f71c5df52dfd2b9b198cce5db27c47707564684ea74986836900107
# 进行运行即可
kubeadm join 192.168.56.20:6443 --token f9lvrz.59mykzssqw6vjh32 \
--discovery-token-ca-cert-hash sha256:4e23156e2f71c5df52dfd2b9b198cce5db27c47707564684ea74986836900107 #请更换成自己的
```
### 3.2node节点初始化失败的解决办法
{% note danger modern %} !!!正常情况不要执行，除非初始化失败 {% endnote %}
```shell
# 1.如果初始化失败，可以通过下面的命令重置本节点
kubeadm reset
```
## 4.安装网络插件
{% note warning flat %} 此时回到控制节点(任意控制节点master节点)，执行以下命令 {% endnote %}
### 4.1先检查安装的k8s集群状态
```shell
kubectl get nodes -o wide
# 此时节点状态为NotReady，因为还没有安装网络插件
```
### 4.2安装网络插件,我们选择calico
```shell
# 下载
wget --no-check-certificate https://projectcalico.docs.tigera.io/archive/v3.25/manifests/calico.yaml
# 修改 calico.yaml 文件
vim calico.yaml
# 在 - name: CLUSTER_TYPE 下方添加如下内容
- name: CLUSTER_TYPE
  value: "k8s,bgp"
  # 下方为新增内容
- name: IP_AUTODETECTION_METHOD
  value: "interface=网卡名称"
# 例如：- name: IP_AUTODETECTION_METHOD
# 例如：  value: "interface=eth0" 可使用通配符，例如：interface="eth.*|en.*"
```
### 4.3控制面板：查看 pods、nodes状态
```shell
kubectl get nodes -o wide
kubectl get pods -A -o wide
```
{% note success flat %} 等待一段时间后，所有节点状态为Ready，表示安装成功🎉🎉🎉 {% endnote %}


本项目参考了xuxiaowei {% referto '[1]','kubernetes（k8s）安装' %} 通过kubeadm安装k8s集群的方法，另外该作者还有一系列gitlab生态的使用教程和介绍，感谢xuxiaowei的分享，也请大家多多支持该作者。 

{% referfrom '[1]','kubernetes（k8s）安装','https://www.yuque.com/xuxiaowei-com-cn/gitlab-k8s/k8s-install' %}