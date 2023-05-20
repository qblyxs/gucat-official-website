---
title: jenkins在kubernetes集群的安装方法
description: jenkins在kubernetes集群的安装方法,并且让jenkins能调用k8s，实现自动化
mathjax: true
tags:
  - kubernetes
  - devops
categories:
  - devops
abbrlink: 20230520c
sticky: 95
swiper_index: 95
date: 2023-05-20 10:19:03
---

## 说明
{% note warning flat %}
本文是基于kubernetes集群的Jenkins安装，请参考官方[基于kubernetes的Jenkins安装](https://www.jenkins.io/doc/book/installing/kubernetes/)。
{% endnote %}
{% note info flat %}安装前请确保已经部署好了可用的kubernetes集群环境。{% endnote %}

## 1. 准备资源清单

### 1.1. 创建命名空间
{% note default flat %} 创建namespace.yaml文件内容如下：{% endnote %}
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
```

### 1.2. 创建Service Account

Service Account用于对容器进行身份验证和授权。Service Account可以被分配到Kubernetes中的Pod中，使得Pod能够以该Service Account的身份与Kubernetes API Server交互。Service Account通常用于访问Kubernetes API资源、管理Secrets和访问其他资源。在Kubernetes中，Service Account是一种OAuth2.0客户端，它使用OAuth2.0协议来获取和验证访问令牌。

{% note default flat %}创建serviceAccount.yaml文件内容如下：{% endnote %}
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-admin
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["*"]

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-admin
  namespace: jenkins

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-admin
subjects:
- kind: ServiceAccount
  name: jenkins-admin
  namespace: jenkins

```

### 1.3. 创建volume
{% note default flat %}创建volume.yaml文件内容如下：{% endnote %}
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv-volume
  labels:
    type: local
spec:
  storageClassName: local-storage
  claimRef:
    name: jenkins-pv-claim
    namespace: jenkins
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  local:
    path: /mnt/jenkins
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k8s-master2

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pv-claim
  namespace: jenkins
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 3Gi
```
<!-- tab -->
1. 注意修改第25行本地挂载路径`path: /mnt/jenkins`
2. 注意修改第33行`values`的值为kubernetes集群中的挂载该PV的节点名称
3. 该节点的该路径需要提前创建好,如我的在`k8s-master2`上创建`mkdir -p /mnt/jenkins`
<!-- endtab -->

### 1.4.创建deployment
{% note default flat %}创建deployment.yaml文件内容如下：{% endnote %}
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      nodeSelector:
        kubernetes.io/hostname: k8s-master2
      securityContext:
            fsGroup: 1000 
            runAsUser: 1000
      serviceAccountName: jenkins-admin
      containers:
        - name: jenkins
          image: jenkins/jenkins:2.387.3-lts-jdk11
          resources:
            limits:
              memory: "2Gi"
              cpu: "1000m"
            requests:
              memory: "500Mi"
              cpu: "500m"
          ports:
            - name: httpport
              containerPort: 8080
            - name: jnlpport
              containerPort: 50000
          livenessProbe:
            httpGet:
              path: "/login"
              port: 8080
            initialDelaySeconds: 90
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 5
          readinessProbe:
            httpGet:
              path: "/login"
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          volumeMounts:
            - name: jenkins-data
              mountPath: /var/jenkins_home         
      volumes:
        - name: jenkins-data
          persistentVolumeClaim:
              claimName: jenkins-pv-claim
```
<!-- tab -->
1. 注意修改第17行`kubernetes.io/hostname`的值为kubernetes集群中的挂载该PV的节点名称,或者删除该行,或者修改为其他label
2. 可修改第24行image镜像版本,这里我使用的是jenkins/jenkins:2.387.3-lts-jdk11

<!-- endtab -->

### 1.5.创建service
{% note default flat %}创建service.yaml文件内容如下：{% endnote %}
```yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/path:   /
      prometheus.io/port:   '8080'
spec:
  selector: 
    app: jenkins
  type: NodePort  
  ports:
    - name: httpport
      port: 8080
      targetPort: 8080
      nodePort: 32000
    - name: jnlpport
      port: 50000
      targetPort: 50000
```
<!-- tab -->
1. 这里我直接指定了service的类型为NodePort,且端口号为32000,如果不指定,则会随机分配一个端口。也可以指定为LoadBalancer,这样就可以通过外部IP访问了。或者指定为ClusterIP,暂时在集群内部访问。
2. service类型可以不强求,因为后面我会配置ingress。

<!-- endtab -->

### 1.6.创建ingress
{% note default flat %}创建ingress.yaml文件内容如下：{% endnote %}
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: jenkins
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: jenkins.example.com
      http:
        paths:
          - backend:
              service:
                name: jenkins
                port:
                  number: 8080
            path: /
            pathType: Prefix
  tls:
    - secretName: jenkins-tls # 储存TLS证书的Kubernetes Secret对象名称
      hosts:
        - jenkins.example.com # 您要将Ingress映射到的标准主机名
```
<!-- tab -->
1. 这里我开启了ssl重定向,所以需要配置ssl证书。
2. 请将13行和26行的`jenkins.example.com`修改为自己的域名。
3. 请将24行的`jenkins-tls`修改为自己的证书名称。
4. 也可以删除tls部分，在ingress服务里配置默认证书。
5. 如果不需要ssl重定向,请删除第7-9行`annotations`部分。
<!-- endtab -->

## 2.部署jenkins
### 2.1.部署jenkins的namespace
{% note info flat %}部署jenkins的jenkins命名空间：{% endnote %}
```bash
kubectl apply -f namespace.yaml
```
### 2.2.部署jenkins的serviceaccount
{% note info flat %}部署jenkins的jenkins-admin serviceaccount：{% endnote %}
```bash
kubectl apply -f serviceAccount.yaml
```
### 2.3.部署jenkins的volume
{% note info flat %}部署jenkins的jenkins-volume：{% endnote %}
```bash
kubectl apply -f volume.yaml
```
### 2.4.部署jenkins的deployment
{% note info flat %}部署jenkins的jenkins deployment：{% endnote %}
```bash
kubectl apply -f deployment.yaml
```
{% note info flat %}查询Pod状态：{% endnote %}
```bash
kubectl get pod -n jenkins
```
{% note success flat %}如果Pod状态为`Running`，则表示基本部署成功{% endnote %}
### 2.5.部署jenkins的service
{% note info flat %}部署jenkins的jenkins service：{% endnote %}
```bash
kubectl apply -f service.yaml
```
### 2.6.部署jenkins的ingress
{% note warning flat %}这里仅限部署了ingress-nginx的用户使用!!{% endnote %}
{% note info flat %}部署jenkins的jenkins ingress：{% endnote %}
```bash
# 如果没有部署ingress-nginx,请删除ingress.yaml文件,并删除下面的命令
# kubectl delete -f ingress.yaml
kubectl apply -f ingress.yaml
```

## 3.访问jenkins
### 3.1.获取jenkins的admin初始密码
{% note info flat %}获取jenkins的admin初始密码：{% endnote %}
```bash
cat /mnt/jenkins/secrets/initialAdminPassword
```
<!-- tab -->
1. 这里我使用的是`/mnt/jenkins/secrets/initialAdminPassword`路径,请根据自己的实际情况修改。
2. 你在volume.yaml文件中定义的是什么路径,jenkins的文件就在哪个路径下。
3. 也可以通过查看pod的日志获取初始密码。 `kubectl logs -f jenkins-xxxxx -n jenkins`
4. 或者通过进入容器内部获取初始密码。 `kubectl exec -it jenkins-xxxxx -n jenkins cat /var/jenkins_home/secrets/initialAdminPassword` 
5. xxxxx为你的jenkins pod名称。
<!-- endtab -->
### 3.2. 访问jenkins的web页面
<!-- tab -->
1. 可通过ingress中配置的域名进行访问
2. 可通过service中配置的nodePort进行访问,IP地址:32000 (32000为service中配置的nodePort)

<!-- endtab -->
### 3.3. 基本配置
<!-- tab -->
1. 在初始化页面中,选择`选择插件来安装`。
2. 做左上角选择`无`,选择`安装`我们不在这里安装插件,而是在后面的`插件管理`中安装。
3. 创建用户或使用admin登录。
<!-- endtab -->
### 3.4. 更换jenkins的插件源
<!-- tab -->
1. 登陆部署了jenkins的服务器。
2. 进入挂载的jenkins目录下的`updates`目录。 我的是`/mnt/jenkins/updates`。
3. 注意,有的人可能看不到updata目录,这是因为你的jenkins初始化界面不是按我的步骤来的,所以没有updata目录。
4. update目录下有个default.json文件,这个文件就是插件源文件。先拷贝一份备份。cp default.json default.json.bak
5. 修改default.json文件,将里面的`https://updates.jenkins.io/download`替换为`https://mirrors.tuna.tsinghua.edu.cn/jenkins`。
6. 将default.json文件中的`https://www.google.com`替换为`https://www.baidu.com`。
7. 重启jenkins服务。`kubectl delete pod jenkins-xxxxx -n jenkins` xxxxx为你的jenkins pod名称。
<!-- endtab -->
{% note info flat %}替换命令如下:{% endnote %}
```bash
sed -i s#https://www.google.com#https://www.baidu.com#g default.json
sed -i s#https://updates.jenkins.io/download#https://mirrors.tuna.tsinghua.edu.cn/jenkins#g default.json
# 也可以使用其他源,比如阿里云的源 sed -i s#https://updates.jenkins.io/download#http://mirrors.tencentyun.com/jenkins#g default.json
# 腾讯云的内网高速源 sed -i s#https://updates.jenkins.io/download#http://mirrors.tencentyun.com/jenkins#g default.json
```
### 3.5. 安装jenkins插件
<!-- tab -->
1. 登陆jenkins,点击左侧菜单栏的`系统管理`。
2. 点击`插件管理`。
3. 点击`可选插件`。
4. 找不到的话直接访问`http://你的jenkins域名/manage/pluginManager/available`。
5. 安装下列插件:
    - Localization: Chinese (Simplified)
    - Pipeline
    - Kubernetes
6. 记得勾选`安装后重启Jenkins`。然后jenkins会自动重启。
7. 小技巧: jenkins支持热重启,访问`http://你的jenkins域名/restart`即可重启jenkins。
8. 重启完成后,jenkins已经是中文界面了。就简单了。
<!-- endtab -->

## 4. 配置jenkins的kubernetes插件
### 4.1. 配置jenkins的kubernetes插件
<!-- tab -->
1. 登陆jenkins,点击左侧菜单栏的`系统管理`。
2. 点击`节点管理`,部分老版本需要在`系统配置`里找到配置kubernetes的界面。
3. 找到`configureClouds`,添加一个`Kubernetes`,新版直接进去配置即可。
4. 名称默认为`kubernetes`,可以自定义。
5. 点击`Kubernetes Cloud details`展开配置。
6. Kubernetes 地址填写`https://kubernetes.default.svc.cluster.local`。
7. 可以填写Kubernetes 命名空间,也可以不填。
8. 直接点击`Test Connection`或者`连接测试`测试连接。
9. Jenkins 地址填写`http://jenkins.jenkins.svc.cluster.local:8080`或者你的jenkins域名。
10. Jenkins 通道 填写`jenkins.jenkins.svc.cluster.local:50000`,jenkins.jenkins第一个jenkins是服务名称,第二个jenkins是命名空间。根据自己的实际情况填写。
11. 然后应用保存即可。
<!-- endtab -->
{% note info flat %}
你可能会在网上看到各种配置服务证书和token的方法,这些方法不适用于我们这种安装方式,不需要配置证书和token,只需要配置上面的内容即可。
{% endnote %}
### 4.2. 关于jenkins的kubernetes插件的说明
<!-- tab -->
1. 需要配置证书和token的情况一般是在jenkins和kubernetes不在同一个集群的情况下。
2. 或者jenkins连接外部集群
3. 或者jenkins的serviceAccount没有权限访问kubernetes的api的情况下。
4. 在kubernetes内部安装的jenkins,不需要配置证书和token,因为我们安装jenkins时配置的serviceAccount默认就有权限访问kubernetes的api。
5. 关于Pod Templates我没有在jenkins里进行配置,需要时直接写到jenkinsfile里即可。后面我会介绍到jenkins如何调用kubernetes的api创建pod,在各种pod里执行任务。
<!-- endtab -->
{% note success flat %}🎉🎉🎉至此kubernetes集成jenkins配置完成!!{% endnote %}