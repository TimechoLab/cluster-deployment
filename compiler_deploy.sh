#!/bin/bash
# 发布脚本，功能为拉取最新代码并发布项目
branchName=$1
commitId=$2
iotdbPath=$3
# if [ -z $branchName ] && [ -n $commitId ];then
#   echo "branchName 和 commitID 只能二选一."
#   exit
# fi
# git项目所在路径
IOTDB_PATH=$iotdbPath
echo "输入参数:"branchName:$branchName commitId:$commitId IOTDB_PATH:$IOTDB_PATH
#保存原始目录
originDir=`pwd`
# 切换到项目目录
cd $IOTDB_PATH
# 使用commitId的方式更新iotdb代码
if [[ -n $branchName ]];then
  echo "branchname" 
  # git_pull=$(git fetch --all)
  git_pull=$(git fetch --all)
  git_pull=$(git checkout $branchName)
  git_pull=$(git pull origin $branchName)
  echo "分支切换完毕，branchName："$branchName
# 使用分支的方式更新代码
elif [[ -n $commitId ]];then
  echo "commitid"
  git_pull=$(git fetch --all)
  git_pull=$(git reset --hard $commitId)
  git_pull=$(git pull)
  echo "分支切换完毕，commitId："$commitId
fi
# 发布代码
echo "开始编译项目"
comp_mvn=$(mvn clean package -pl distribution -am -DskipTests)
if [ $? -eq 0 ]; then
		echo "编译完成！"
else
  echo "编译失败！"$comp_mvn
  echo "operation_exit"
  exit
fi
cd $originDir
# 让整个程序执行，放开如下的注释即可
# echo "operation_exit"
# echo "error"
# 发布好的项目在${IOTDB_PATH}/distribution/target/apache-iotdb-*-all-bin/apache-iotdb-*-all-bin/*
