#!/bin/bash

################基础配置参数，需要模型审视修改##################
# 必选字段(必须在此处定义的参数): Network batch_size RANK_SIZE
# 网络名称，同目录名称
Network="ResNet50_for_PyTorch"
# 训练batch_size，网络中对bs做了除以机器数量的计算，故32p脚本此处扩大为8p的4倍
batch_size=16384
# 训练使用的npu卡数
export RANK_SIZE=32
export RANK_ID_START=0
# 数据集路径,保持为空,不需要修改
data_path=""
conf_path=""
server_index=""
fix_node_ip=""

# 训练epoch 90
train_epochs=90
# 加载数据进程数
workers=128

# 参数校验，data_path为必传参数，其他参数的增删由模型自身决定；此处新增参数需在上面有定义并赋值
for para in $*
do
    if [[ $para == --data_path* ]];then
        data_path=`echo ${para#*=}`
    elif [[ $para == --conf_path* ]];then
            conf_path=`echo ${para#*=}`
    elif [[ $para == --server_index* ]];then
            server_index=`echo ${para#*=}`
    elif [[ $para == --fix_node_ip* ]];then
            fix_node_ip=`echo ${para#*=}`
    fi
done

# 校验是否传入data_path,不需要修改
if [[ $data_path == "" ]];then
    echo "[Error] para \"data_path\" must be confing"
    exit 1
fi

one_node_ip=`find $conf_path -name "server_*0.info"|awk -F "server_" '{print $2}'|awk -F "_" '{print $1}'`
linux_num=`find $conf_path -name "server_*.info" |wc -l`

export HCCL_IF_IP=$fix_node_ip
export MASTER_ADDR=$one_node_ip

###############指定训练脚本执行路径###############
# cd到与test文件夹同层级目录下执行脚本，提高兼容性；test_path_dir为包含test文件夹的路径
cur_path=`pwd`
cur_path_last_dirname=${cur_path##*/}
if [ x"${cur_path_last_dirname}" == x"test" ];then
    test_path_dir=${cur_path}
    cd ..
    cur_path=`pwd`
else
    test_path_dir=${cur_path}/test
fi


#################创建日志输出目录，不需要修改#################

for((RANK_ID=$RANK_ID_START;RANK_ID<$((RANK_SIZE+RANK_ID_START));RANK_ID++));
do
    #设置环境变量，不需要修改
    export ASCEND_DEVICE_ID=$RANK_ID
    echo "Device ID: $ASCEND_DEVICE_ID"



    #创建DeviceID输出目录，不需要修改
    if [ -d ${test_path_dir}/output/${ASCEND_DEVICE_ID} ];then
        rm -rf ${test_path_dir}/output/${ASCEND_DEVICE_ID}
        mkdir -p ${test_path_dir}/output/$ASCEND_DEVICE_ID/ckpt
    else
        mkdir -p ${test_path_dir}/output/$ASCEND_DEVICE_ID/ckpt
    fi

    echo run process ${RANK_ID}

    #SOLVER.MAX_ITER 82000 \
    #执行训练脚本，以下传参不需要修改，其他需要模型审视修改
done

#################启动训练脚本#################
# 训练开始时间，不需要修改
start_time=$(date +%s)
# 非平台场景时source 环境变量
check_etp_flag=`env | grep etp_running_flag`
etp_flag=`echo ${check_etp_flag#*=}`
if [ x"${etp_flag}" != x"true" ];then
    source ${test_path_dir}/env_npu.sh
fi

export NODE_RANK=${server_index}
export NPU_WORLD_SIZE=`awk 'BEGIN{printf "%.0f\n",8*'${linux_num}'}'`

nohup python3.7 ./DistributedResnet50/main_apex_d76_npu.py \
        --data ${data_path} \
        --addr=$one_node_ip \
        --seed=49 \
        --workers=${workers} \
        --learning-rate=4.9 \
        --warmup=8 \
        --label-smoothing=0.1 \
        --mom=0.9 \
        --weight-decay=1.0e-04  \
        --static-loss-scale=128 \
        --print-freq=1 \
        --dist-url='tcp://127.0.0.1:50000' \
        --dist-backend='hccl' \
        --multiprocessing-distributed \
        --world-size=4 \
        --rank=0 \
        --benchmark=0 \
        --device='npu' \
        --epochs=${train_epochs} \
        --batch-size=${batch_size} > ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log 2>&1 &

wait


##################获取训练数据################
# 训练结束时间，不需要修改
end_time=$(date +%s)
e2e_time=$(( $end_time - $start_time ))

batch_size=4096
# 训练用例信息，不需要修改
BatchSize=${batch_size}
DeviceType=`uname -m`
CaseName=${Network}_bs${BatchSize}_${RANK_SIZE}'p'_'acc'

# 结果打印，不需要修改
echo "------------------ Final result ------------------"
# 输出性能FPS，需要模型审视修改
grep "FPS@all" ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log | awk '{print $11}' >> ${test_path_dir}/output/$ASCEND_DEVICE_ID/train_${CaseName}_fps.log
FPS=`cat ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_fps.log | awk '{a+=$1} END {if (NR != 0) printf("%.3f",a*4/NR)}'`
# 打印，不需要修改
echo "Final Performance images/sec : $FPS"

# 输出训练精度,需要模型审视修改
train_accuracy=`grep -a '* Acc@1'  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk 'END {print}'|awk -F "Acc@1" '{print $NF}'|awk -F " " '{print $1}'`
# 打印，不需要修改
echo "Final Train Accuracy : ${train_accuracy}"
echo "E2E Training Duration sec : $e2e_time"

# 性能看护结果汇总
# 获取性能数据，不需要修改
# 吞吐量
ActualFPS=${FPS}
# 单迭代训练时长
TrainingTime=`awk 'BEGIN{printf "%.2f\n", '${batch_size}'*1000/'${FPS}'}'`

# 从train_$ASCEND_DEVICE_ID.log提取Loss到train_${CaseName}_loss.txt中，需要根据模型审视
grep Epoch: ${test_path_dir}/output/$ASCEND_DEVICE_ID/train_$ASCEND_DEVICE_ID.log|grep -v Test|awk -F "Loss" '{print $NF}' | awk -F " " '{print $1}' >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt

# 最后一个迭代loss值，不需要修改
ActualLoss=`awk 'END {print}'  ${test_path_dir}/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt`

# 关键信息打印到${CaseName}.log中，不需要修改
echo "Network = ${Network}" >  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "RankSize = ${RANK_SIZE}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "BatchSize = ${BatchSize}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "DeviceType = ${DeviceType}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "CaseName = ${CaseName}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "ActualFPS = ${ActualFPS}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "TrainingTime = ${TrainingTime}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "TrainAccuracy = ${train_accuracy}" >> ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "ActualLoss = ${ActualLoss}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "E2ETrainingTime = ${e2e_time}" >>  ${test_path_dir}/output/$ASCEND_DEVICE_ID/${CaseName}.log