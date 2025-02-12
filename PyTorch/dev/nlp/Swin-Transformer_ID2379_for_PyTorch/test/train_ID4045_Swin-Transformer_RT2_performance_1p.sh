#!/bin/bash
source /usr/local/Ascend/latest/bin/setenv.bash
#当前路径,不需要修改
cur_path=`pwd`
export ASCEND_SLOG_PRINT_TO_STDOUT=0
export NPU_CALCULATE_DEVICE=$ASCEND_DEVICE_ID
#集合通信参数,不需要修改


export HCCL_WHITELIST_DISABLE=1
export MASTER_ADDR=127.0.0.1
export MASTER_PORT=23456
export RANK=0
export WORLD_SIZE=1


export RANK_SIZE=1
export JOB_ID=10087
RANK_ID_START=0

#进入到conda环境

#source activate py8

for para in $*
do
    if [[ $para == --data_path* ]];then
        data_path=`echo ${para#*=}`
    elif [[ $para == --conda_name* ]];then
        conda_name=`echo ${para#*=}`
        source set_conda.sh
        source activate $conda_name
    fi
done

#pip3 uninstall timm -y
#pip3 install timm==0.4.5
#pip3 install diffdist==0.1

#pip3 show torch >1.txt
#sed -i "s|is_cuda|is_npu|g"  /home/anaconda3/envs/py8/lib/python3.7/site-packages/torch/nn/modules/batchnorm.py
# 数据集路径,保持为空,不需要修改
data_path=""

#基础参数，需要模型审视修改
#网络名称，同目录名称
Network="Swin-Transformer_RT2_ID4045_for_PyTorch"
#训练epoch
train_epochs=1
#训练batch_size
batch_size=64
#训练step
#train_steps=`expr 1281167 / ${batch_size}`
#学习率
learning_rate=0.495

#TF2.X独有，不需要修改
#export NPU_LOOP_SIZE=${train_steps}

#维测参数，precision_mode需要模型审视修改
precision_mode="allow_mix_precision"
#维持参数，以下不需要修改
over_dump=False
data_dump_flag=False
data_dump_step="10"
profiling=False
autotune=False
bin_mode=False
PREC=""

# 帮助信息，不h需要修改
if [[ $1 == --help || $1 == -h ]];then
    echo"usage:./train_performance_1p.sh <args>"
    echo " "
    echo "parameter explain:
    --precision_mode         precision mode(allow_fp32_to_fp16/force_fp16/must_keep_origin_dtype/allow_mix_precision)
    --over_dump                 if or not over detection, default is False
    --data_dump_flag         data dump flag, default is False
    --data_dump_step         data dump step, default is 10
    --profiling                 if or not profiling for performance debug, default is False
    --data_path                 source data of training
    -h/--help                 show help message
    "
    exit 1
fi

#参数校验，不需要修改
for para in $*
do
    if [[ $para == --precision_mode* ]];then
        apex_opt_level=`echo ${para#*=}`
                    if [[ $apex_opt_level != "O1" ]] && [[ $apex_opt_level != "O2" ]] && [[ $apex_opt_level != "O3" ]]; then
                            echo "[ERROR] para \"precision_mode\" must be config O1 or O2 or O3"
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
    elif [[ $para == --bin_mode* ]];then
        bin_mode="True"
    fi
done

#校验是否传入data_path,不需要修改
if [[ $data_path == "" ]];then
    echo "[Error] para \"data_path\" must be confing"
    exit 1
fi

#训练开始时间，不需要修改
start_time=$(date +%s)

#进入训练脚本目录，需要模型审视修改
cd $cur_path/../

# 添加二进制代码
line=`grep "import torch" moby_main.py -n | tail -1|awk -F ':' '{print $1}'`
sed -i "$[line+1]itorch.npu.set_compile_mode(jit_compile=False)" moby_main.py

#新增模糊编译接口
if [ $bin_mode == "True" ];then
    sed -i "67itorch.npu.set_compile_mode(jit_compile=False)" ${cur_path}/main.py
fi
#kill残余的此网络进程
#ps -ef | grep moby | awk '{print $2}' | xargs kill -9

sed -i "s|EPOCHS: 300|EPOCHS: 1|g"  configs/moby_swin_tiny.yaml
rm -rf output
sed -i "s|TRAIN.EPOCHS = 300|TRAIN.EPOCHS = 1|g" config.py
sed -i "s|pass|break|g" moby_main.py

#mkdir -p checkpoints
#mkdir -p /root/.cache/torch/hub/checkpoints
#cp $data_path/fcn_* /root/.cache/torch/hub/checkpoints

for((RANK_ID=$RANK_ID_START;RANK_ID<$((RANK_SIZE+RANK_ID_START));RANK_ID++));
do
    #设置环境变量，不需要修改
    echo "Device ID: $ASCEND_DEVICE_ID"
    export RANK_ID=$RANK_ID
    
    
    
    #创建DeviceID输出目录，不需要修改
    if [ -d ${cur_path}/output/${ASCEND_DEVICE_ID} ];then
        rm -rf ${cur_path}/output/${ASCEND_DEVICE_ID}
        mkdir -p ${cur_path}/output/$ASCEND_DEVICE_ID/ckpt
    else
        mkdir -p ${cur_path}/output/$ASCEND_DEVICE_ID/ckpt
    fi
    
    #绑核，不需要绑核的模型删除，需要绑核的模型根据实际修改
    #cpucount=`lscpu | grep "CPU(s):" | head -n 1 | awk '{print $2}'`
    #cpustep=`expr $cpucount / 8`
    #echo "taskset c steps:" $cpustep
    #let a=RANK_ID*$cpustep
    #let b=RANK_ID+1
    #let c=b*$cpustep-1

    #执行训练脚本，以下传参不需要修改，其他需要模型审视修改
    nohup python3 moby_main.py $PREC --cfg configs/moby_swin_tiny.yaml --local_rank 0 --data-path $data_path --batch-size ${batch_size} > ${cur_path}/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log 2>&1 &
done 
wait

#恢复参数
sed -i "s|TRAIN.EPOCHS = 1|TRAIN.EPOCHS = 300|g" config.py
sed -i "s|EPOCHS: 1|EPOCHS: 300|g"  configs/moby_swin_tiny.yaml
sed -i "s|break|pass|g" moby_main.py

#kill残余的此网络进程
#ps -ef | grep moby | awk '{print $2}' | xargs kill -9

#退出conda环境
conda deactivate

#训练结束时间，不需要修改
end_time=$(date +%s)
e2e_time=$(( $end_time - $start_time ))

#结果打印，不需要修改
echo "------------------ Final result ------------------"
#输出性能FPS，需要模型审视修改
FPS=`grep FPS $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|awk -F "FPS:" '{print $2}'|tail -n +2|awk '{sum+=$1} END {print"",sum/NR}'|sed s/[[:space:]]//g`
#FPS=`awk 'BEGIN{printf "%.2f\n",'${batch_size}'*'${perf}'}'`


#打印，不需要修改
echo "Final Performance images/sec : $FPS"

#输出训练精度,需要模型审视修改
#train_accuracy=`grep eval_accuracy $cur_path/output/${ASCEND_DEVICE_ID}/train_${ASCEND_DEVICE_ID}.log|grep -v mlp_log|awk 'END {print $5}'| sed 's/,//g' |cut -c 1-5`
#打印，不需要修改
#echo "Final Train Accuracy : ${train_accuracy}"
echo "E2E Training Duration sec : $e2e_time"

#稳定性精度看护结果汇总
#训练用例信息，不需要修改
BatchSize=${batch_size}
DeviceType=`uname -m`
CaseName=${Network}_bs${BatchSize}_${RANK_SIZE}'p'_'perf'

##获取性能数据
#吞吐量，不需要修改
ActualFPS=${FPS}
#单迭代训练时长，不需要修改
TrainingTime=`awk 'BEGIN{printf "%.2f\n",'${BatchSize}'/'${FPS}'}'`

#从train_$ASCEND_DEVICE_ID.log提取Loss到train_${CaseName}_loss.txt中，需要根据模型审视
grep "Train" $cur_path/output/$ASCEND_DEVICE_ID/train_$ASCEND_DEVICE_ID.log|awk -F "loss " '{print $2}'|awk -F " " '{print $1}'|awk NF > $cur_path/output/$ASCEND_DEVICE_ID/train_${CaseName}_loss.txt

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
#echo "TrainAccuracy = ${train_accuracy}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "ActualLoss = ${ActualLoss}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log
echo "E2ETrainingTime = ${e2e_time}" >> $cur_path/output/$ASCEND_DEVICE_ID/${CaseName}.log


#sed -i "s|is_npu|is_cuda|g"  /home/anaconda3/envs/py8/lib/python3.7/site-packages/torch/nn/modules/batchnorm.py

