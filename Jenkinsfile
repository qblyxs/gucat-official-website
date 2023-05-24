// 定义全局变量
// def DOCKER_REGISTRY = ''
def imageType = 'nginx'  // 镜像类型
def nodeSelector = 'jenkins-slave=dev'  // k8s-slave运行节点标签
def gitRepoUrl = 'https://gitee.com/qblyxs/gucat-official-website.git'  // git仓库地址
def branch = 'dev'  // git分支
def gitCredentialsId = 'gitee-auth-qblyxs'  // git认证信息
def gitPrivRepoUrl = 'https://gitee.com/qblyxs/gucat-website-data.git'  // 项目私有数据,使用时请删除相关代码
def imageName = 'qblyxs/gucat-web-nginx'  // 镜像名称
// def imageTag = '1.0.${BUILD_NUMBER}-dev'  // 镜像标签
def imageTag = '1.1.0-dev'  // 镜像标签


// 注意事项
// 1. secretVolume.secretName.'kaniko-secret' 需要提前在k8s集群中创建 kubectl create secret -n devops-tools generic kaniko-secret --from-file=/path/config.json
// 2. config.json中的"auth"字段及认证信息需要base64加密后填入 例如: echo -n username:password | base64
// 3. jenkins-slave=dev 需要提前在k8s集群中创建 kubectl label node k8s-node2 jenkins-slave=dev

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
        stage('拉取公共代码') {
            git branch: "${branch}", credentialsId: "${gitCredentialsId}", url: "${gitRepoUrl}"
        }
        stage('拉取私有代码') {
            try {
                git branch: master, credentialsId: "${gitCredentialsId}", url: "${gitPrivRepoUrl}"
            }
            catch (err) {
                echo '没有找到私有数据'
            }
            finally {
                echo '继续执行'
            }
        }
        stage('操作文件') {
            try {
                sh 'ls -al'
                sh 'mv -r ./blog_data/* ./blog/'
            }
            catch (err) {
                echo '没有找到blog_data数据'
            }
            } 
        if (imageType == 'node') {
            echo '如果项目为node项目,该过程将会在Dockerfile中进行构建'
        }
        else if (imageType == 'nginx') {
            stage('node正在进行构建') {
                container('node') {
                    stage('Build a Node project') {
                        sh 'node -v'
                        sh 'npm config set registry https://registry.npmmirror.com'
                        sh 'npm install -g hexo-cli'
                        sh 'cd blog && npm install' 
                        timeout(time:20, unit:'SECONDS') {
                            echo '等待程序包准备中...'}
                        sh 'cd blog && hexo generate -f'
                        sh 'ls ./blog/public'
                    }
                }   
            }
        }
        else if (imageType == 'other') {
            echo '预留过程'
        }
        else {
            echo '请输入正确的镜像标签'
        }
        stage('使用kaniko构建镜像并推送DockerHub') {     
            container('kaniko') {
                // 使用jenkins进行认证
                stage('Build a Container') {
                    // 等待镜像准备完成
                    timeout(time:10, unit:'SECONDS') {
                        echo '等待镜像准备中...'}
                    sh "ls /kaniko/.docker/"
                    sh "ls "
                    if (imageType == 'node') {
                        sh "/kaniko/executor --context=. --destination=${imageName}:${imageTag}"
                    }
                    else if (imageType == 'nginx') {
                        sh "/kaniko/executor --dockerfile=./nginx/Dockerfile --context=./nginx --destination=${imageName}:${imageTag}"
                    }
                    else {
                        echo 'error'
                    }
                    // sh "/kaniko/executor --dockerfile=./python/Dockerfile --context=./python --destination=${imageNamePython}:${imageTagPython}"
                }
            }
        }
    }
}