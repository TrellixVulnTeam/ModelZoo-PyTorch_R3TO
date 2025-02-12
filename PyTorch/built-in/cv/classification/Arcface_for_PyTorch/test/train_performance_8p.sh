#!/bin/bash

################基础配置参数，需要模型审视修改##################
# 必选字段(必须在此处定义的参数): Network batch_size RANK_SIZE
# 网络名称，同目录名称
Network="ArcFace_for_PyTorch"

export WORLD_SIZE=8
export MASTER_ADDR='127.0.0.1'
export MASTER_PORT='12581'

# 训练使用的npu卡数
export RANK_SIZE=8
RANK_ID_START=0
# 模型结构
arch="arcface"
# 数据集路径,保持为空,不需要修改
data_path=""

# 参数校验，data_path为必传参数，其他参数的增删由模型自身决定；此处新增参数需在上面有定义并赋值
for para in $*
do
    if [[ $para == --data_path* ]];then
        data_path=`echo ${para#*=}`
    fi
done

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

export NODE_RANK=0
#################启动训练脚本#################
# 训练开始时间，不需要修改
start_time=$(date +%s)
# 非平台场景时source 环境变量
check_etp_flag=`env | grep etp_running_flag`
etp_flag=`echo ${check_etp_flag#*=}`
if [ x"${etp_flag}" != x"true" ];then
    source ${test_path_dir}/env_npu.sh
fi

for((RANK_ID=$RANK_ID_START;RANK_ID<$((RANK_SIZE+RANK_ID_START));RANK_ID++));
do
    # 设置环境变量，不需要修改
    export RANK=$RANK_ID
    ASCEND_DEVICE_ID=$RANK_ID

    # 创建DeviceID输出目录，不需要修改
    if [ -d ${test_path_dir}/output/${ASCEND_DEVICE_ID} ];then
        rm -rf ${test_path_dir}/output/${ASCEND_DEVICE_ID}
        mkdir -p ${test_path_dir}/output/${ASCEND_DEVICE_ID}
    else
        mkdir -p ${test_path_dir}/output/${ASCEND_DEVICE_ID}
    fi

    if [ $(uname -m) = "aarch64" ]
    then
        KERNEL_NUM=$(($(nproc)/8))
        PID_START=$((KERNEL_NUM * RANK_ID))
        PID_END=$((PID_START + KERNEL_NUM - 1))
        taskset -c $PID_START-$PID_END python3 -u train.py \
            configs/glint360k_r100.py \
            --local_rank=${RANK_ID} --perf_only > ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log 2>&1 &
    else
        python3 -u train.py \
            configs/glint360k_r100.py \
            --local_rank=${RANK_ID} --perf_only > ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log 2>&1 &
    fi
done

wait

##################获取训练数据################
ASCEND_DEVICE_ID=0

# 训练结束时间，不需要修改
end_time=$(date +%s)
e2e_time=$(( $end_time - $start_time ))

training_log=${test_path_dir}/output/${ASCEND_DEVICE_ID}/training_${ASCEND_DEVICE_ID}.log
grep "Training" ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log >> ${training_log}

# 训练用例信息，不需要修改
BatchSize=`grep "total_batch_size" ${training_log} |awk '{print $5}'`
DeviceType=`uname -m`
CaseName=${Network}_bs${BatchSize}_${RANK_SIZE}'p'_'acc'

# 结果打印，不需要修改
echo "------------------ Final result ------------------"
# 输出性能FPS，需要模型审视修改
grep "Speed" ${training_log} |awk '{print $4}' >> ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_fps.log
FPS=`cat ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_fps.log |tail -n 100 |awk '{a+=$1} END {if (NR != 0) printf("%.3f",a/NR)}'`
# 打印，不需要修改
echo "Final Performance images/sec : $FPS"

# 输出训练精度,需要模型审视修改
lfw_accuracy_log=${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_lfw_accuracy.log
cfp_fp_accuracy_log=${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_cfp_fp_accuracy.log
agedb_30_accuracy_log=${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_agedb_30_accuracy.log

grep "lfw" ${training_log} >> ${lfw_accuracy_log}
grep "cfp_fp" ${training_log} >> ${cfp_fp_accuracy_log}
grep "agedb_30" ${training_log} >> ${agedb_30_accuracy_log}

train_lfw_accuracy_highest=`grep -a 'Accuracy-Highest' ${lfw_accuracy_log} |awk 'END {print $4}'`
train_cfp_fp_accuracy_highest=`grep -a 'Accuracy-Highest' ${cfp_fp_accuracy_log} |awk 'END {print $4}'`
train_agedb_30_accuracy_highest=`grep -a 'Accuracy-Highest' ${agedb_30_accuracy_log} |awk 'END {print $4}'`
train_accuracy="'lfw': ${train_lfw_accuracy_highest} 'cfp_fp': ${train_cfp_fp_accuracy_highest} 'agedb_30': ${train_agedb_30_accuracy_highest}"

# 打印，不需要修改
echo "Final Train Accuracy : ${train_accuracy}"
echo "E2E Training Duration sec : $e2e_time"

# 性能看护结果汇总
# 获取性能数据，不需要修改
# 吞吐量
ActualFPS=${FPS}
# 单迭代训练时长
TrainingTime=`awk 'BEGIN{printf "%.2f\n", '${BatchSize}'*1000/'${FPS}'}'`

# 从training_log提取Loss到train_${CaseName}_loss.txt中，需要根据模型审视
grep -rns "Loss" ${training_log} |awk -F " " '{print $7}' >> ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_loss.txt

# 倒数第二个迭代loss值，不需要修改
ActualLoss=`tail -n 2 ${test_path_dir}/output/${ASCEND_DEVICE_ID}/train_${CaseName}_loss.txt |awk 'NR==1 {print}'`

# 关键信息打印到${CaseName}.log中，不需要修改
echo "Network = ${Network}" >  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "RankSize = ${RANK_SIZE}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "BatchSize = ${BatchSize}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "DeviceType = ${DeviceType}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "CaseName = ${CaseName}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "ActualFPS = ${ActualFPS}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "TrainingTime = ${TrainingTime}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "TrainAccuracy = ${train_accuracy}" >> ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "ActualLoss = ${ActualLoss}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log
echo "E2ETrainingTime = ${e2e_time}" >>  ${test_path_dir}/output/${ASCEND_DEVICE_ID}/${CaseName}.log