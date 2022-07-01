#!/bin/bash
__current_dir=$(
   cd "$(dirname "$0")"
   pwd
)
args=$@
__os=`uname -a`

function log() {
   message="[Pika Log]: $1 "
   echo -e "${message}" 2>&1 | tee -a ${__current_dir}/install.log
}
set -a
__local_ip=$(hostname -I|cut -d" " -f 1)
source ${__current_dir}/install.conf
if [ -f ~/.pkrc ];then
  source ~/.pkrc > /dev/null
  echo "存在已安装的 Pika, 安装目录为 ${PK_BASE}, 执行升级流程"
elif [ -f /usr/local/bin/pkctl ];then
  PK_BASE=$(cat /usr/local/bin/pkctl | grep PK_BASE= | awk -F= '{print $2}' 2>/dev/null)
  echo "存在已安装的 Pika, 安装目录为 ${PK_BASE}, 执行升级流程"
else
  PK_BASE=$(cat ${__current_dir}/install.conf | grep PK_BASE= | awk -F= '{print $2}' 2>/dev/null)
  echo "安装目录为 ${PK_BASE}, 开始进行安装"
fi
set +a


log "拷贝安装文件到目标目录"

mkdir -p ${PK_BASE}
cp -rv --suffix=.$(date +%Y%m%d-%H%M) ./pika/* ${PK_BASE}/

# 记录Pika安装路径
echo "PK_BASE=${PK_BASE}" > ~/.pkrc
# 安装 pkctl 命令
cp pkctl /usr/local/bin && chmod +x /usr/local/bin/pkctl
ln -s /usr/local/bin/pkctl /usr/bin/pkctl 2>/dev/null

log "======================= 开始安装 ======================="
#Install docker & docker-compose
##Install Latest Stable Docker Release
if which docker >/dev/null; then
   log "检测到 Docker 已安装，跳过安装步骤"
   log "启动 Docker "
   service docker start 2>&1 | tee -a ${__current_dir}/install.log
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker"
      cp docker/bin/* /usr/bin/
      cp docker/service/docker.service /etc/systemd/system/
      chmod +x /usr/bin/docker*
      chmod 754 /etc/systemd/system/docker.service
      log "... 启动 docker"
      service docker start 2>&1 | tee -a ${__current_dir}/install.log

   else
      log "... 在线安装 docker"
      curl -fsSL https://get.docker.com -o get-docker.sh 2>&1 | tee -a ${__current_dir}/install.log
      sudo sh get-docker.sh --mirror Aliyun 2>&1 | tee -a ${__current_dir}/install.log
      log "... 启动 docker"
      service docker start 2>&1 | tee -a ${__current_dir}/install.log
   fi

fi

# 检查docker服务是否正常运行
docker ps 1>/dev/null 2>/dev/null
if [ $? != 0 ];then
   log "Docker 未正常启动，请先安装并启动 Docker 服务后再次执行本脚本"
   exit
fi

##Install Latest Stable Docker Compose Release
if which docker-compose >/dev/null; then
   log "检测到 Docker Compose 已安装，跳过安装步骤"
else
   if [[ -d docker ]]; then
      log "... 离线安装 docker-compose"
      cp docker/bin/docker-compose /usr/bin/
      chmod +x /usr/bin/docker-compose
   else
      log "... 在线安装 docker-compose"
      curl -L https://get.daocloud.io/docker/compose/releases/download/v2.2.3/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose 2>&1 | tee -a ${__current_dir}/install.log
      chmod +x /usr/local/bin/docker-compose
      ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
   fi
fi
# 检查docker-compose是否正常
docker-compose version 1>/dev/null 2>/dev/null
if [ $? != 0 ];then
   log "docker-compose 未正常安装，请先安装 docker-compose 后再次执行本脚本"
   exit
fi

# 将配置信息存储到安装目录的环境变量配置文件中
echo '' >> ${PK_BASE}/.env
cp -f ${__current_dir}/install.conf ${PK_BASE}/install.conf.example
# 通过加载环境变量的方式保留已修改的配置项，仅添加新增的配置项
source ${__current_dir}/install.conf
source ~/.pkrc >/dev/null 2>&1
source ${PK_BASE}/.env
# 把原来kafka的配置合并成IP
if [ ${PK_KAFKA_HOST} = 'kafka' ];then
  PK_KAFKA_HOST=${__local_ip}
fi
env | grep PK_ > ${PK_BASE}/.env
ln -s ${PK_BASE}/.env ${PK_BASE}/install.conf 2>/dev/null
grep "127.0.0.1 $(hostname)" /etc/hosts >/dev/null || echo "127.0.0.1 $(hostname)" >> /etc/hosts
pkctl generate_compose_files
pkctl config 1>/dev/null 2>/dev/null
if [ $? != 0 ];then
   pkctl config
   log "docker-compose 版本与配置文件不兼容或配置文件存在问题，请重新安装最新版本的 docker-compose 或检查配置文件"
   exit
fi

cd ${__current_dir}

log "启动服务"
pkctl down -v 2>&1 | tee -a ${__current_dir}/install.log
pkctl up -d 2>&1 | tee -a ${__current_dir}/install.log

pkctl status 2>&1 | tee -a ${__current_dir}/install.log

echo -e "======================= 安装完成 =======================\n" 2>&1 | tee -a ${__current_dir}/install.log
echo -e "您可以使用命令 'pkctl status' 检查服务运行情况.\n" 2>&1 | tee -a ${__current_dir}/install.log-a ${__current_dir}/install.log
