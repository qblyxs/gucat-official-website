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