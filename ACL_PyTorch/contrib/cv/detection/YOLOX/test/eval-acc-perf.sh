#!/bin/bash

set -eu

datasets_path="/root/datasets/"

for para in $*
do
    if [[ $para == --datasets_path* ]]; then
        datasets_path=`echo ${para#*=}`
    fi
done

arch=`uname -m`
rm -rf ./prep_data
python Yolox_preprocess.py --dataroot ${datasets_path} --output './prep_data'

if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

python gen_dataset_info.py bin ./prep_data ./prep_bin.info 640 640
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

source /usr/local/Ascend/ascend-toolkit/set_env.sh
rm -rf result/dumpOutput_device*

./benchmark.${arch} -model_type=vision -device_id=0 -batch_size=1 -om_path=./models/yolox_x_bs1.om -input_text_path=./prep_bin.info -input_width=640 -input_height=640 -output_binary=True -useDvpp=False
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

mv result/dumpOutput_device0 result/dumpOutput_device0_bs1



python Yolox_postprocess.py --dataroot ${datasets_path} --dump_dir 'result/dumpOutput_device0_bs1'
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi


echo "====performance data===="
python test/parse.py result/perf_vision_batchsize_1_device_0.txt

if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
echo "success"

