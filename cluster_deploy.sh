#!/bin/bash
function validateParam() {
  echo "初始化参数为 branch_name:"$1 "commit_id:"$2 "confignode_ips:"$3 "datanode_ips:"$4 "deploy_path:"$5 "server_account:"$6 "iotdb_git_path:"$7
  if [ -z $1 ] && [ -z $2 ]; then
    echo "branch_name和commit_id必须其中一个参数不为空"
    exit
  elif [ -z $3 ]; then
    echo "参数confignode_ips不能为空"
    exit
  elif [ -z $4 ]; then
    echo "参数datanode_ips不能为空"
    exit
  elif [ -z $5 ]; then
    echo "参数deploy_path[iotdb在服务器上的路径]不能为空"
    exit
  elif [ -z $6 ]; then
    echo $6
    echo "参数server_account[服务器的用户名]不能为空"
    exit
  elif [ -z $7 ]; then
    echo $7
    echo "参数iotdb_git_path不能为空"
    exit
  fi
}
declare -A initParams
for line in $(cat config.ini | sed '/^$/d'); do
  # format[xxx]
  if [[ $line =~ ^\[.*\] ]]; then
    [[ $line =~ ^\[(.*)\] ]]
    currentFile=${BASH_REMATCH[1]}
  # ignore #xxx
  elif [[ $line =~ ^\# ]]; then
    doNothing=""
  # parse key=value
  elif [ -n $line ] && [ $line != '\n' ]; then
    key=$(echo $line | awk -F= '{gsub(" |\t","",$1); print $1}')
    value=$(echo $line | awk -F= '{gsub(" |\t","",$2); print $2}')
    if [[ $currentFile == deployment ]]; then
      initParams[$key]=$value
    fi
  fi
done
# 进行参数验证
validateParam "${initParams[branch_name]}" "${initParams[commit_id]}" ${initParams[confignode_ips]} ${initParams[datanode_ips]} ${initParams[deploy_path]} ${initParams[server_account]} ${initParams[iotdb_git_path]}
# confignode的ip list
confignodeIpsStr=${initParams[confignode_ips]}
confignodeIps=(${confignodeIpsStr//,/ })
# datanode的ip list
datanodeIpsStr=${initParams[datanode_ips]}
datanodeIps=(${datanodeIpsStr//,/ })
# 发布到服务器上的路径
deployPath=${initParams[deploy_path]}
# 服务器的用户名
userNameOfServer=${initParams[server_account]}
# echo "开始部署项目 ..."
#result=`bash compiler_deploy.sh "${initParams[branch_name]}" "${initParams[commit_id]}" ${initParams[iotdb_git_path]}`
#exit_evl $result
# iotdb工程所在的目录
iotdbPath=""
if [ ! -z ${initParams[iotdb_deploy_path]} ];then
  iotdbPath=${initParams[iotdb_deploy_path]}
else
  iotdbPath=${initParams[iotdb_git_path]}/distribution/target/apache-iotdb-*-all-bin/apache-iotdb-*-all-bin/
fi
echo "开始复制项目到服务器 ..."
bash remote_copy.sh $confignodeIpsStr $datanodeIpsStr $deployPath $userNameOfServer $iotdbPath
echo "项目复制到服务器结束 ..."
echo "开始替换配置并启动服务器 ..."
bash replace_start.sh $confignodeIpsStr $datanodeIpsStr $deployPath $userNameOfServer
echo "替换配置并启动服务器结束 ..."