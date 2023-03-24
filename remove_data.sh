#!/bin/bash
alias ssh="ssh -o stricthostkeychecking=no"
confignodeIpsStr=$1
confignodeIps=(${confignodeIpsStr//,/ })
echo "当前的confignode ip:"${confignodeIps[1]} ${confignodeIps[2]} ${confignodeIps[0]}
# datanode的ip list
datanodeIpsStr=$2
datanodeIps=(${datanodeIpsStr//,/ })
# iotdb被复制到服务器的目录
deployPath=$3
# 服务器的用户名
account=$4
# 当前发布好的iotdb所在的目录
localSoftPath=$5
# 添加一个默认路劲，防止路径错误导致系统文件被删除
remoteSoftPath=$deployPath/iotdb
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
for ip in ${confignodeIps[@]};do
  echo "开始清理"$ip
  # 将服务器的服务停止
  echo "kill ConfigNode ..."
  closeServer ConfigNode $ip
  echo "remove data and logs ..."
  ssh ${account}@${ip} "rm -rf ${remoteSoftPath}/logs > /dev/null 2>&1 &"
  ssh ${account}@${ip} "rm -rf ${remoteSoftPath}/data > /dev/null 2>&1 &"
  # echo "configNode已经复制到"${deployPath}"中,"当前的目录结构为$dir
done
for ip in ${datanodeIps[@]};do
  echo "开始清理"$ip
  # 将服务器的服务停止
  echo "kill DataNode ..."
  closeServer DataNode $ip
  echo "remove data and logs ..."
  ssh ${account}@${ip} "rm -rf ${remoteSoftPath}/logs > /dev/null 2>&1 &"
  ssh ${account}@${ip} "rm -rf ${remoteSoftPath}/data > /dev/null 2>&1 &"
done
