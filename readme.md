# 脚本使用指南
## 一、目录结构介绍
`cluster_deploy.sh` 完整部署的调用脚本，负责调用其余3个脚本完成集群的整个工作
`compiler_deploy.sh` 编译项目和本地打包脚本，负责代码更新以及项目的打包操作,可独立运行
`remote_copy.sh` 远程复制脚本，负责将本地打包好的项目负责到远程服务器上，可独立运行
`replace_start.sh` 负责远端服务中配置替换工作和项目启动工作，替换的配置在`config.ini`文件中进行配置，可独立运行
`config.ini` 自定义配置，根据该配置替换远端服务的配置

## 二、项目启动
### 2.1 config.ini配置说明

**语法说明:**
1. `#`开头，代表注释
2. `[*]`,固定值，目前只支持`datanode-env.sh`,`iotdb-datanode.properties`,`iotdb-metric.yml`,`iotdb-confignode.properties`,`confignode-env.sh`,`deployment ` 6种
3. `primitive_array_size=16`,对应的配置项  
4. 注意最左边不允许有空格，如果配置的`value`为带引号的，需使用\"进行转义   


**datanode-env.sh模块**  
对应`DataNode`服务器`datanode-env.sh`配置文件中的配置，为固定值，目前只支持`MAX_HEAP_SIZE`,`HEAP_NEWSIZE`,`MAX_DIRECT_MEMORY_SIZE`3个参数  

**iotdb-datanode.properties模块**  
对应`DataNode服务器``iotdb-datanode.properties`配置文件中的配置，为任意值。  
特别注意的是，如果存在以`^$key`开头的配置，则使用配置替换，如果不存在，则首先会匹配`^ #$key`,如果有则会在对应行下新增配置，否则会在最后一行新增配置。  

**iotdb-metric.yml模块**  
对应`DataNode``ConfigNode`中iotdb-metric.yml配置文件的配置，使用`^$key`进行匹配  

**confignode-env.sh模块**  
对应`ConfigNode`服务器`confignode-env.sh`配置文件中的配置，为固定值，目前只支持`MAX_HEAP_SIZE`,`HEAP_NEWSIZE`,`MAX_DIRECT_MEMORY_SIZE`3个参数  

**iotdb-confignode.properties模块**  
对应`ConfigNode服务器``iotdb-confignode.properties`配置文件中的配置，为任意值。  
特别注意的是，如果存在以`^$key`开头的配置，则使用配置替换，如果不存在，则首先会匹配`^ #$key`,如果有则会在对应行下新增配置，否则会在最后一行新增配置。  

**deployment模块**  
该模块中主要配置和脚本启动参数相关的变量。  

示例：  
```sh
#注意值如果值需要加",需要使用\"进行转义，如MAX_HEAP_SIZE=\"3G\"
[datanode-env.sh]
MAX_HEAP_SIZE=\"3G\"
HEAP_NEWSIZE=\"2G\"
MAX_DIRECT_MEMORY_SIZE=\"3G\"
[iotdb-datanode.properties]
primitive_array_size=16
write_read_schema_free_memory_proportion=4:2:2:2
[iotdb-metric.yml]
prometheusExporterPort=907
[confignode-env.sh]
#本配置只支持这三个参数的修改
MAX_HEAP_SIZE=\"3G\"
HEAP_NEWSIZE=\"2G\"
MAX_DIRECT_MEMORY_SIZE=\"3G\"
[iotdb-confignode.properties]
schema_replication_factor=1
data_replication_factor=1
schema_region_consensus_protocol_class=org.apache.iotdb.consensus.ratis.RatisConsensus
[deployment]
# 分支名,和commit_id二选一
branch_name=master
# git提交记录的commitId，和branch_name二选一
# commit_id=
# ConfigNode服务器的ip，多个以,号进行连接
confignode_ips=192.168.1.222,192.168.1.174,192.168.1.218
# DataNode服务器的ip，多个以,号进行连接
datanode_ips=192.168.1.222,192.168.1.174,192.168.1.218
# 发布到服务器上的地址
deploy_path=/root/temp
# ConfigNode和DataNode服务器的用户名，注意多个服务器用户名需要一致
server_account=root
# IoTDB Git仓库地址
iotdb_git_path=/home/mltest/iotdb
# 发布好的iotdb包所在的位置，如果没有配置则默认为$iotdb_git_path/distribution/target/apache-iotdb-*-all-bin/apache-iotdb-*-all-bin/
iotdb_deploy_path=/home/mltest/zhy_test/
```

### 2.2 脚本使用

> 默认会依次调用`compiler_deploy.sh`脚本，`remote_copy.sh`脚本，`replace_start.sh`脚本进行部署工作

示例:  
`bash cluster_deploy.sh`    
**脚本初始化参数配置:**   
需要在`config.ini`配置文件的`[deployment]`模块下配置如下的参数    
branch_name,分支的名字,与commit_id二选一    
commit_id，commitid，与branch_name二选一  
confignode_ips，ConfigNode的ip列表  
datanode_ips，DataNode的ip列表  
deploy_path，发布到服务器上的地址路径，注意实际路径为 `$deploy_path/iotdb`  
server_account，服务器的用户名  
iotdb_git_path，iotdb所在Git仓库的路径 
iotdb_deploy_path,iotdb发布好的包所在的路径，如果没有配置则默认为$iotdb_git_path/distribution/target/apache-iotdb-*-all-bin/apache-iotdb-*-all-bin/

**脚本替换变量说明**  
脚本会替换config.ini中配置的变量  
脚本会替换与集群ip相关的变量，如下：  
iotdb-confignode.properties中internal_address为对应服务器的ip  
iotdb-confignode.properties中target_config_nodes为第一个confignode_ips的ip  
iotdb-datanode.properties中internal_address为对应服务器的ip  
iotdb-datanode.properties中rpc_address为对应服务器的ip  
iotdb-datanode.properties中target_config_nodes为confignode_ips中配置的所有ip  

### 2.3 `compiler_deploy.sh`脚本的使用  

示例：    
`bash compiler_deploy.sh "master" "" /f/workspace1/iotdb`  
**参数介绍:**    
参数1,分支的名字,与参数2二选一  
参数2，commitid，与参数1二选一  
参数3，iotdb git工程所在的路径  

### 2.4 `remote_copy.sh`脚本的使用  

示例：    
`bash remote_copy.sh 192.168.1.222,192.168.1.174,192.168.1.218 192.168.1.222,192.168.1.174,192.168.1.218 /root/temp root /f/workspace1/iotdb`  
**参数介绍:**    
参数1，ConfigNode的ip列表  
参数2，DataNode的ip列表  
参数3，发布到服务器上的地址路径，注意实际路径为 `参数5/iotdb`  
参数4，服务器的用户名  
参数5，控制机中Iotdb包所在的路径  

### 2.5 `replace_start.sh`脚本的使用 

示例：    
`bash replace_start.sh 192.168.1.222,192.168.1.174,192.168.1.218 192.168.1.222,192.168.1.174,192.168.1.218 /root/temp root`  
**参数介绍:**    
参数1，ConfigNode的ip列表  
参数2，DataNode的ip列表  
参数3，发布到服务器上的地址路径，注意实际路径为 `参数5/iotdb`  
参数4，服务器的用户名  

### 2.6 `stop_all.sh` 脚本的使用
示例: `bash stop_all.sh`  
**脚本说明**  
1. 脚本会从config.ini配置文件的`deployment` 模块中获取`confignode_ips`,`datanode_ips`,`deploy_path`,`server_account`中配置的4个参数
2. 脚本会默认执行`confignode_ips`,`datanode_ips`机器的$deploy_path/iotdb/xxnode/sbin/stop_xxnode.sh的停止脚本，停止服务。其中`xx`代表ConfigNode或DataNode的脚本

### 2.7 `start_all.sh` 脚本的使用
示例: `bash start_all.sh`  
**脚本说明**  
1. 脚本会从config.ini配置文件的`deployment` 模块中获取`confignode_ips`,`datanode_ips`,`deploy_path`,`server_account`中配置的4个参数
2. 脚本会默认执行`confignode_ips`,`datanode_ips`机器的$deploy_path/iotdb/xxnode/sbin/start_xxnode.sh的停止脚本，停止服务。其中`xx`代表ConfigNode或DataNode的脚本。

## 脚本使用前置
1. 控制机(脚本运行的机器)需要和各集群的集群配置ssh免密登录
2. 控制机需要配置好jdk（版本为1.8及以上），git,maven
3. 集由群机器需要配置好jdk,注意于脚本使用的是ssh方式进行远程服务启动，所以需要在集群的部署用户目录的~/.bashrc中添加jdk的变量(添加到文件的第二行)，否则脚本运行jdk相关的指令不成功。




