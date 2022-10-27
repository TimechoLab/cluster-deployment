#!/bin/bash
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
# confignode的ip list
confignodeIpsStr=${initParams[confignode_ips]}
confignodeIps=(${confignodeIpsStr//,/ })
# datanode的ip list
datanodeIpsStr=${initParams[datanode_ips]}
datanodeIps=(${datanodeIpsStr//,/ })
# 发布到服务器上的路径
deployPath=${initParams[deploy_path]}
# 服务器的用户名
account=${initParams[server_account]}
function validateParam() {
  if [ -z $1 ]; then
    echo "参数confignode_ips不能为空"
    exit
  elif [ -z $2 ]; then
    echo "参数datanode_ips不能为空"
    exit
  elif [ -z $3 ]; then
    echo "参数deploy_path[iotdb在服务器上的路径]不能为空"
    exit
  elif [ -z $4 ]; then
    echo "参数server_account[服务器的用户名]不能为空"
    exit
  fi
}
validateParam $confignodeIpsStr $datanodeIpsStr $deployPath $account
# 检查是否启动成功
function checkStatus(){
  key=$1
  ip=$2
  checkNum=0
  retry=0
  while [ $retry -le 2 ];do
    result=$(ssh ${account}@${ip} "jps | grep -w $key | grep -v grep | wc -l")
    if [ "$result" == "1" ]; then
      echo "${ip} $key已启动 ..."
      checkNum=$((${checkNum}+1))
      break
    else
      retry=$((${retry} + 1))
      # echo "${ip} $key启动中，等待5s..."
      sleep 5
      continue
    fi
  done
  if [ $retry -gt 2 ];then
    echo "${ip} $key启动失败 ..."
  fi
  return $checkNum
}
configNodeCheckNum=0
# 启动confignode服务
confignodeStopShell=$deployPath/iotdb/sbin/start-confignode.sh
for ip in ${confignodeIps[@]};do
    echo "开始启动$ip的ConfigNode"
    ssh ${account}@${ip} "bash $confignodeStopShell > /dev/null 2>&1 &"
    checkStatus ConfigNode $ip 
    configNodeCheckNum=$(($configNodeCheckNum+$?))
done
#启动datanode服务
datanodeStopShell=$deployPath/iotdb/datanode/sbin/start-datanode.sh
for ip in ${datanodeIps[@]};do
    echo "开始启动$ip的DataNode"
    ssh ${account}@${ip} "bash $datanodeStopShell  > /dev/null 2>&1 &"
done
datanodeCheckNum=0
for ip in ${datanodeIps[@]};do
    checkStatus DataNode $ip
    datanodeCheckNum=$(($datanodeCheckNum+$?))
done
if [ "$configNodeCheckNum" == "${#confignodeIps[*]}" ] && [ "$datanodeCheckNum" == "${#datanodeIps[*]}"  ];then
  echo "集群启动成功 ..."
else
  echo "集群启动失败 ..."
fi
