#!/bin/bash

#export ASCEND_SLOG_PRINT_TO_STDOUT=1 

#当前路径,不需要修改
cur_path=`pwd`

#集合通信参数,不需要修改
export RANK_SIZE=8
export JOB_ID=10087
RANK_ID_START=0


# 数据集路径,保持为空,不需要修改
data_path=""

#基础参数，需要模型审视修改
#网络名称，同目录名称
Network="vit-base_RT2_ID4040_for_PyTorch"
#训练epoch
train_epochs=10000
#训练batch_size
batch_size=64
#训练step
train_steps=
#学习率
learning_rate=0.1

#TF2.X独有，需要模型审视修改
#export NPU_LOOP_SIZE=${train_steps}

#维测参数，precision_mode需要模型审视修改
PREC=""
#维持参数，以下不需要修改
over_dump=False
data_dump_flag=False
data_dump_step="10"
profiling=False

# 帮助信息，不需要修改
if [[ $1 == --help || $1 == -h ]];then
    echo"usage:./train_performance_1P.sh <args>"
    echo " "
    echo "parameter explain:
    --precision_mode         precision mode(O0/O1/O2/O3)
    --over_dump		           if or not over detection, default is False
    --data_dump_flag		     data dump flag, default is False
    --data_dump_step		     data dump step, default is 10
    --profiling		           if or not profiling for performance debug, default is False
    --data_path		           source data of training
    -h/--help		             show help message
    "
    exit 1
fi

#参数校验，不需要修改
for para in $*
do
    if [[ $para == --precision_mode* ]];then
        apex_opt_level=`echo ${para#*=}`
        if [[ $apex_opt_level != "O1" ]] && [[ $apex_opt_level != "O2" ]] && [[ $apex_opt_level != "O3" ]]; then
            echo "[Error] para \"precision_mode\" must be config O1 or O2 or O3"
            exit 1
        fi
        PREC="--apex --apex-opt-level "$apex_opt_level
    elif [[ $para == --over_dump* ]];then
        over_dump=`echo ${para#*=}`
        over_dump_path=${cur_path}/output/overflow_dump
        mkdir -p ${over_dump_path}
    elif [[ $para == --data_dump_flag* ]];then
        data_dump_flag=`echo ${para#*=}`
        data_dump_path=${cur_path}/output/data_dump
        mkdir -p ${data_dump_path}
    elif [[ $para == --data_dump_step* ]];then
        data_dump_step=`echo ${para#*=}`
    elif [[ $para == --profiling* ]];then
        profiling=`echo ${para#*=}`
        profiling_dump_path=${cur_path}/output/profiling
        mkdir -p ${profiling_dump_path}
    elif [[ $para == --data_path* ]];then
        data_path=`echo ${para#*=}`
    elif [[ $para == --ckpt_path* ]];then
      ckpt_path=`echo ${para#*=}`
    fi
done

#校验是否传入data_path,不需要修改
if [[ $data_path == "" ]];then
    echo "[Error] para \"data_path\" must be confing"
    exit 1
fi

#添加二进制代码
line=`grep "import torch" ${cur_path}/../train.py -n | tail -1|awk -F ':' '{print $1}'`
sed -i "$[line+1]itorch.npu.set_compile_mode(jit_compile=False)" ${cur_path}/../train.py

#训练开始时间，不需要修改
start_time=$(date +%s)

#进入训练脚本目录，需要模型审视修改
cd $cur_path

export MASTER_ADDR=localhost
export MASTER_PORT=29688
export HCCL_WHITELIST_DISABLE=1

NPUS=($(seq 0 7))
export NPU_WORLD_SIZE=${#NPUS[@]}
rank=0
for i in ${NPUS[@]}
do
    mkdir -p  $cur_path/output/${i}/
    export NPU_CALCULATE_DEVICE=${i}
    export ASCEND_DEVICE_ID=${i}
    export RANK=${rank}
    echo run process ${rank}
    python3 $cur_path/../train.py  \
        --name cifar10-100_500 \
        --dataset cifar10 \
        --model_type ViT-B_16  \
        --pretrained_dir ${ckpt_path}/ViT-B_16.npz \
        --addr=127.0.0.1 \
        --train_batch_size=64 \
        --num_steps=1000 \
        --npu-fused-sgd \
        --fp16 \
        --learning_rate  0.24 \
        --data_dir ${data_path} \
        --ddp True \
        --fp16_opt_level O2  > ${cur_path}/output/${ASCEND_DEVICE_ID}/train_${i}.log 2>&1 &
    let rank++
done
wait

#训练结束时间，不需要修改
end_time=$(date +%s)
e2e_time=$(( $end_time - $start_time ))

sed -i "s|\r|\n|g"  ${cur_path}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log
#结果打印，不需要修改
echo "------------------ Final result ------------------"
#输出性能FPS，需要模型审视修改
FPS=`grep FPS $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk -F "FPS=" '{print$2}' | awk -F ")" '{print$1}' |tail -n +5 |awk '{sum+=$1} END {print"",sum/NR}'|sed s/[[:space:]]//g`
FPS=$(awk 'BEGIN{print '$FPS'*8}')
#打印，不需要修改
echo "Final Performance images/sec : $FPS"

#输出训练精度,需要模型审视修改
#train_accuracy=`grep "Prec@5:" $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk -F ":" 'END {print $8}'|cut -c 1-6`
train_accuracy=`grep -a "Best Accuracy:" $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk '{print$NF}'`

#打印，不需要修改
echo "Final Train Accuracy : ${train_accuracy}"
#echo "Final Train Accuracy(top5) : ${train_accuracy}"
echo "E2E Training Duration sec : $e2e_time"

#性能看护结果汇总
#训练用例信息，不需要修改
BatchSize=${batch_size}
DeviceType=`uname -m`
CaseName=${Network}_bs${BatchSize}_${RANK_SIZE}'p'_'acc'

##获取性能数据，不需要修改
#吞吐量
ActualFPS=${FPS}
#单迭代训练时长
TrainingTime=`awk 'BEGIN{printf "%.2f\n",'${BatchSize}'*1000/'${ActualFPS}'}'`


#从train_$ASCEND_DEVICE_ID.log提取Loss到train_${CaseName}_loss.txt中，需要根据模型审视
#grep "Training" $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk '{print$2,$6}'|awk -F "(" '{print$2,$3}'|sort  -k 1,1 -u -n |awk -F '=' '{print$2}'|awk -F ')' '{print$1}'|awk '{if(length !=0) print $0}'  > $cur_path/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt
grep "Steps" $cur_path/output/$ASCEND_DEVICE_ID/train_$ASCEND_DEVICE_ID.log|grep -v X |awk -F "loss=" '{print$2}' | awk -F ")" '{print$1}'|sed '/^$/d' > $cur_path/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt
#最后一个迭代loss值，不需要修改
ActualLoss=`awk 'END {print}' $cur_path/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt`

#关键信息打印到${CaseName}.log中，不需要修改
echo "Network = ${Network}" > $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "RankSize = ${RANK_SIZE}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "BatchSize = ${BatchSize}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "DeviceType = ${DeviceType}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "CaseName = ${CaseName}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "ActualFPS = ${ActualFPS}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "TrainingTime = ${TrainingTime}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "TrainAccuracy = ${train_accuracy}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "ActualLoss = ${ActualLoss}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "E2ETrainingTime = ${e2e_time}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log