#!/bin/bash
alias ssh="ssh -o stricthostkeychecking=no"
# configNode的ip list
confignodeIpsStr=$1
confignodeIps=(${confignodeIpsStr//,/ })
# datanode的ip list
datanodeIpsStr=$2
datanodeIps=(${datanodeIpsStr//,/ })
deployPath=$3
account=$4
# 用来判断当前是哪个文件
currentFile=""
# iotdb所在的根目录
softBaseDir=$deployPath/iotdb
# confignode配置文件的根目录
confignodeBaseDir=$softBaseDir
# datanode配置文件的根目录
datanodeBaseDir=$softBaseDir
confignodePort=10710
declare -A datanodeEnvMap
declare -A iotdbDatanodeMap
declare -A iotdbConfignodeMetricMap
declare -A iotdbDatanodeMetricMap
declare -A confignodeEnvMap
declare -A iotdbConfignodeMap
declare -A iotdbCommonMap

# 启动集群
function closeServer(){
  key=$1
  ip=$2
  result=`ssh ${account}@${ip} "jps|grep $key"`
  if [[ -z $result ]];then
    return
  fi
  pid=`echo $result | awk '{print $1}'`
  ssh ${account}@${ip} "kill -9 $pid"
}
#启动IoTDB ConfigNode节点
echo "开始启动confignode ... "
for ip in ${confignodeIps[@]};do
  # echo "kill ConfigNode ..."
  closeServer ConfigNode $ip
  echo "准备启动ConfigNode： $ip ..."
  pid3=$(ssh ${account}@${ip} "bash ${confignodeBaseDir}/sbin/start-confignode.sh  > /dev/null 2>&1 &")
  #主节点需要先启动，所以等待10秒是为了保证主节点启动完毕
  sleep 10
done
check_config_num=0
for ip in ${confignodeIps[@]};do
  for ((t_wait = 0; t_wait <= 3; t_wait++)); do
    str1=$(ssh ${account}@${ip} "jps | grep -w ConfigNode | grep -v grep | wc -l")
    if [ "$str1" == "1" ]; then
      echo "${ip} ConfigNode已启动 ..."
      check_config_num=$((${check_config_num} + 1))
      break
    else
      echo "${ip} ConfigNode未启动 ..."
      sleep 5
      continue
    fi
  done
done
if [ $check_config_num != ${#confignodeIps[*]} ];then
  echo "${#confignodeIps[*]}个ConfigNode没有全部启动成功，集群部署失败."
  exit
fi
#启动IoTDB ConfigNode节点
echo "开始启动datanode ..."
check_data_num=0
for ip in ${datanodeIps[@]};do
  # echo "kill DataNode ..."
  closeServer DataNode $ip
  echo "准备启动DataNode： $ip ..."
  pid3=$(ssh ${account}@${ip} "bash ${datanodeBaseDir}/sbin/start-datanode.sh  > /dev/null 2>&1 &")
  #主节点需要先启动，所以等待10秒是为了保证主节点启动完毕
  sleep 10
done
for ip in ${datanodeIps[@]};do
  for ((t_wait = 0; t_wait <= 3; t_wait++)); do
    str1=$(ssh ${account}@${ip} "jps | grep -w DataNode | grep -v grep | wc -l")
    if [ "$str1" == "1" ]; then
      echo "${ip} DataNode已启动"
      check_data_num=$((${check_data_num} + 1))
      break
    else
      echo "${ip} DataNode未启动"
      sleep 30
      continue
    fi
  done
done
echo "datanode启动完成"

#根据检查结果进行下一步操作
if [ "$check_config_num" == "${#confignodeIps[*]}" ] && [ "$check_data_num" == "${#datanodeIps[*]}" ]; then
  echo "全部集群已启动"
else
  echo "部署集群环境失败"
fi

