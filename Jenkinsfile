// 定义全局变量
// def DOCKER_REGISTRY = ''
def imageType = 'none'  // 镜像类型 node nginx qexo other none
def nodeSelector = 'jenkins-slave=dev'  // k8s-slave运行节点标签
def gitRepoUrl = 'https://gitee.com/qblyxs/gucat-official-website.git'  // git仓库地址
def branch = 'master'  // git分支
def gitCredentialsId = 'gitee-auth-qblyxs'  // git认证信息
def gitPrivRepoUrl = 'https://gitee.com/qblyxs/gucat-website-data.git'  // 项目私有数据,使用时请删除相关代码
def imageName = 'qblyxs/gucat-web'  // 镜像名称
// def imageTag = '1.0.${BUILD_NUMBER}-dev'  // 镜像标签
def imageTag = '1.2.0'  // 镜像标签
def robotID = '9527'  // 机器人ID

// jenkins变量
def pipelineName = env.JOB_NAME
def buildNumber = env.BUILD_NUMBER
def buildUrl = env.BUILD_URL
// 注意事项
// 1. secretVolume.secretName.'kaniko-secret' 需要提前在k8s集群中创建 kubectl create secret -n devops-tools generic kaniko-secret --from-file=/path/config.json
// 2. config.json中的"auth"字段及认证信息需要base64加密后填入 例如: echo -n username:password | base64
// 3. jenkins-slave=dev 需要提前在k8s集群中创建 kubectl label node k8s-node2 jenkins-slave=dev
// 4. 机器人需要提前在企业微信中创建

podTemplate(
    nodeSelector: "${nodeSelector}",
    containers: [
    containerTemplate(name: 'jnlp', image: 'jenkins/inbound-agent:4.13.3-1-jdk11', command: '', args: '${computer.jnlpmac} ${computer.name}'),
    containerTemplate(name: 'node', image: 'node:20.1-alpine', command: 'sleep', args: '99d'),
    containerTemplate(name: 'kaniko', image: 'qblyxs/kaniko:v1.9.2-debug', command: 'sleep', args: '10d')],
    volumes: [
    secretVolume(secretName: 'kaniko-secret', mountPath: '/kaniko/.docker/')
    ]
    )     {
    node(POD_LABEL) {
        stage('流水线开始通知') {
            wxwork(
                robot: "${robotID}",
                type: 'markdown',
                text: [
                    """
                    -----------------------  
                    ### GUCAT自动化构建开始    
                    > 项目名称: ${pipelineName}  
                    > 构建编号: ${buildNumber}  
                    > 构建日志: [${pipelineName}#${buildNumber}](${BUILD_URL}/console)
                    """
                    ]  // 发送的文本消息内容，可以自定义
            )
        }
        stage('拉取公共代码') {
            git branch: "${branch}", credentialsId: "${gitCredentialsId}", url: "${gitRepoUrl}"                 
        }
        stage('拉取私有代码') {
            def secondaryDirectory = "blog_data"      //新的仓库代码存放目录      
            try {
                dir(secondaryDirectory) {
                    git branch: 'master', credentialsId: "${gitCredentialsId}", url: "${gitPrivRepoUrl}"
                }
            }
            catch (err) {
                echo '没有找到私有数据'
            }
            finally {
                echo '继续执行'
            }
        }
        timeout(time:20, unit:'SECONDS') {
            echo '等待数据准备中...'}        

        if (imageType == 'node') {
            echo '如果项目为node项目,该过程将会在Dockerfile中进行构建'
        }
        else if (imageType == 'nginx') {
            stage('node正在进行构建') {
                container('node') {
                    stage('操作文件') {
                        try {
                            sh 'ls -al'
                            sh 'mkdir -p ./blog'
                            sh " yes | cp -rf  ./blog_data/* ./blog/"  // 强制将私有数据拷贝到项目中
                        }
                        catch (err) {
                            echo '没有找到blog_data数据'
                        }
                        } 
                    stage('Build 构建项目') {
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
        else if (imageType == 'none') {
            echo '您选择了不构建镜像'
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
                    switch (imageType) {
                        case 'node': 
                            sh "/kaniko/executor --dockerfile=./node/Dockerfile --context=. --destination=${imageName}-${imageType}:${imageTag}"
                            break
                        case 'nginx': 
                            sh "/kaniko/executor --dockerfile=./nginx/Dockerfile --context=. --destination=${imageName}-${imageType}:${imageTag}"
                            break
                        case 'qexo': 
                            sh "/kaniko/executor --dockerfile=./qexo/Dockerfile --context=. --destination=${imageName}-${imageType}:${imageTag}"
                            break
                        case 'other': 
                            echo '预留过程'
                            break
                        case 'none': 
                            echo '您选择了不构建镜像'
                            break
                        default: 
                            echo '请输入正确的镜像标签'
                            break
                    }
                }
            }
        }
        stage('流水线结果通知') {
            def messageResult = """
            ### GUCAT自动化构建结果  
            > 项目名称: ${pipelineName}  
            > 构建编号: ${buildNumber}
            """

            if (currentBuild.result == null || currentBuild.result == 'SUCCESS') {
                messageResult += """
                > 构建状态: 😃成功🎉
                > 镜像名称是：[${imageType}:${imageTag}](https://hub.docker.com/repository/docker/${imageName}-${imageType})  
                > 构建日志: [${pipelineName}#${buildNumber}](${BUILD_URL}/console)
                """
                wxwork(
                    robot: "${robotID}",
                    type: 'markdown',
                    text: [
                        """
                        ${messageResult}  
                        -----------------------
                        """
                    ]
                )
            } else {
                messageResult += """
                > 构建状态: 😔失败💥  
                > 构建日志: [${pipelineName}#${buildNumber}](${BUILD_URL}/console)  
                """
                wxwork(
                    robot: "${robotID}",
                    type: 'markdown',
                    text: [
                        """
                        ${messageResult}  
                        -----------------------
                        """
                    ]
                )
            }
        }
    }
}