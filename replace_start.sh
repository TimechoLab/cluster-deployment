#!/bin/bash
shopt -s expand_aliases
alias ssh="ssh -o stricthostkeychecking=no"
alias scp="scp -o stricthostkeychecking=no"
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
for line in $(cat config.ini | sed '/^$/d'); do
  # format[xxx]
  if [[ $line =~ ^\[.*\] ]]; then
    [[ $line =~ ^\[(.*)\] ]]
    currentFile=${BASH_REMATCH[1]}
  # ignore #xxx
  elif [[ $line =~ ^\#.* ]]; then
    doNothing=""
  # parse key=value
  elif [ -n $line ] && [ $line != '\n' ]; then
    key=$(echo $line | awk -F= '{gsub(" |\t","",$1); print $1}')
    value=$(echo $line | awk -F= '{gsub(" |\t","",$2); print $2}')
    if [[ $currentFile == datanode-env.sh ]]; then
      datanodeEnvMap[$key]=$value
    elif [[ $currentFile == iotdb-datanode.properties ]]; then
      iotdbDatanodeMap[$key]=$value
    elif [[ $currentFile == iotdb-confignode-metric.yml ]]; then
      iotdbConfignodeMetricMap[$key]=$value
    elif [[ $currentFile == iotdb-datanode-metric.yml ]]; then
      iotdbDatanodeMetricMap[$key]=$value
    elif [[ $currentFile == confignode-env.sh ]]; then
      confignodeEnvMap[$key]=$value
    elif [[ $currentFile == iotdb-confignode.properties ]]; then
      iotdbConfignodeMap[$key]=$value
    elif [[ $currentFile == iotdb-common.properties ]]; then
        iotdbCommonMap[$key]=$value
    fi
  fi
done
# 替换和ip地址相关的配置
for ip in ${confignodeIps[@]}; do
  ssh ${account}@${ip} "sed -i 's/^cn_internal_address.*$/cn_internal_address=${ip}/g' ${confignodeBaseDir}/conf/iotdb-confignode.properties"
  ssh ${account}@${ip} "sed -i 's/^cn_target_config_node_list.*$/cn_target_config_node_list=${confignodeIps[0]}:${confignodePort}/g' ${confignodeBaseDir}/conf/iotdb-confignode.properties"
done
# 数组的长度
len=${#confignodeIps[*]}
tempD=()
i=0
while [ $i -lt $len ]
do
  tempD[$i]=${confignodeIps[$i]}:${confignodePort}
  let i++
done
str=${tempD[*]}
configNodeIpsStr=${str// /,}
for ip in ${datanodeIps[@]}; do
  ssh ${account}@${ip} "sed -i 's/^dn_internal_address.*$/dn_internal_address=${ip}/g' ${datanodeBaseDir}/conf/iotdb-datanode.properties"
  ssh ${account}@${ip} "sed -i 's/^dn_rpc_address.*$/dn_rpc_address=${ip}/g' ${datanodeBaseDir}/conf/iotdb-datanode.properties"
  ssh ${account}@${ip} "sed -i 's/^dn_target_config_node_list.*$/dn_target_config_node_list=${configNodeIpsStr}/g' ${datanodeBaseDir}/conf/iotdb-datanode.properties"
done
function replaceParam(){
  key=$1
  value=$2
  filePath=$3
  # 先查找当前的配置是否在存在于配置文件中，如果不存在，则直接插入配置，存在则替换配置
  findValue=`ssh ${account}@${ip} "grep ^$key ${filePath}"`
  if [ -z $findValue ];then
    # 获取行号，行号可能为空
#    rowNum=`ssh ${account}@${ip} "grep -n '^# $key' ${filePath} | awk -F: '{print \\\$1}'"`
#    if [ -z $rowNum ];then
    ssh ${account}@${ip} "sed -i '1a${key}=${value}' ${filePath}"
#    else
#      ssh ${account}@${ip} "sed -i '${rowNum}a${key}=${value}' ${filePath}"
#    fi
  else
    ssh ${account}@${ip} "sed -i 's/^${key}.*$/${key}=${value}/g' ${filePath}"
  fi
}
# 替换confignode中的配置
echo "开始替换confignode的配置 ..."
for ip in ${confignodeIps[@]}; do
  for key in ${!iotdbConfignodeMetricMap[@]}; do
    ssh ${account}@${ip} "sed -i 's/^${key}.*$/${key}: ${iotdbConfignodeMetricMap[$key]}/g' ${confignodeBaseDir}/conf/iotdb-confignode-metric.yml"
    # ssh ${account}@${ip} "sed -i \"s/^prometheusExporterPort.*$/prometheusExporterPort: 9091/g\" ${confignodeBaseDir}/conf/iotdb-confignode-metric.yml"
  done
  for key in ${!confignodeEnvMap[@]}; do
    if [[ $key == MAX_HEAP_SIZE ]]; then
      ssh ${account}@${ip} "sed -i 's/^#MAX_HEAP_SIZE=\\\"2G\\\".*$/${key}=${confignodeEnvMap[$key]}/g' ${confignodeBaseDir}/conf/confignode-env.sh"
    elif [[ $key == HEAP_NEWSIZE ]]; then
      ssh ${account}@${ip} "sed -i 's/^#HEAP_NEWSIZE=\\\"2G\\\".*$/${key}=${confignodeEnvMap[$key]}/g' ${confignodeBaseDir}/conf/confignode-env.sh"
    else
      ssh ${account}@${ip} "sed -i 's/^${key}.*$/${key}=${confignodeEnvMap[$key]}/g' ${confignodeBaseDir}/conf/confignode-env.sh"
    fi
  done
  for key in ${!iotdbConfignodeMap[@]}; do
    replaceParam $key ${iotdbConfignodeMap[$key]} ${confignodeBaseDir}/conf/iotdb-confignode.properties
  done
  for key in ${!iotdbCommonMap[@]}; do
    replaceParam $key ${iotdbCommonMap[$key]} ${confignodeBaseDir}/conf/iotdb-common.properties
    # ssh ${account}@${ip} "sed -i \"s/^${key}.*$/${key}=${iotdbDatanodeMap[$key]}/g\" ${datanodeBaseDir}/conf/iotdb-datanode.properties"
  done
done
echo "confignode配置结束 ..."
# 替换datanode中的配置
echo "开始替换datanode的配置 ..."
for ip in ${datanodeIps[@]}; do
  for key in ${!datanodeEnvMap[@]}; do
    if [ $key == MAX_HEAP_SIZE ]; then
      ssh ${account}@${ip} "sed -i 's/^#MAX_HEAP_SIZE=\\\"2G\\\".*$/${key}=${datanodeEnvMap[$key]}/g' ${datanodeBaseDir}/conf/datanode-env.sh"
    elif [ $key == HEAP_NEWSIZE ]; then
      ssh ${account}@${ip} "sed -i 's/^#HEAP_NEWSIZE=\\\"2G\\\".*$/${key}=${datanodeEnvMap[$key]}/g' ${datanodeBaseDir}/conf/datanode-env.sh"
    else
      ssh ${account}@${ip} "sed -i 's/^${key}.*$/${key}=${datanodeEnvMap[$key]}/g' ${datanodeBaseDir}/conf/datanode-env.sh"
    fi
  done
  for key in ${!iotdbDatanodeMap[@]}; do
    replaceParam $key ${iotdbDatanodeMap[$key]} ${datanodeBaseDir}/conf/iotdb-datanode.properties
    # ssh ${account}@${ip} "sed -i \"s/^${key}.*$/${key}=${iotdbDatanodeMap[$key]}/g\" ${datanodeBaseDir}/conf/iotdb-datanode.properties"
  done
  for key in ${!iotdbDatanodeMetricMap[@]}; do
    ssh ${account}@${ip} "sed -i 's/^${key}.*$/${key}: ${iotdbDatanodeMetricMap[$key]}/g' ${datanodeBaseDir}/conf/iotdb-datanode-metric.yml"
    # ssh ${account}@${ip} "sed -i \"s/^prometheusExporterPort:.*$/prometheusExporterPort: 9093/g\" ${datanodeBaseDir}/conf/iotdb-datanode-metric.yml"
  done
  for key in ${!iotdbCommonMap[@]}; do
    replaceParam $key ${iotdbCommonMap[$key]} ${datanodeBaseDir}/conf/iotdb-common.properties
    # ssh ${account}@${ip} "sed -i \"s/^${key}.*$/${key}=${iotdbDatanodeMap[$key]}/g\" ${datanodeBaseDir}/conf/iotdb-datanode.properties"
  done
done
echo ”datanode的配置更新完成 ...“
echo "集群配置已经更新完成 ... "
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
