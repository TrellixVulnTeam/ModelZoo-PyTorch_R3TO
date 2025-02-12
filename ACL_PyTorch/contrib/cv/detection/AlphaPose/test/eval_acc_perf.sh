#!/bin/bash

set -eu

datasets_path="./data/coco"

for para in $*
do
    if [[ $para == --datasets_path* ]]; then
        datasets_path=`echo ${para#*=}`
    fi
done

arch=`uname -m`
rm -rf ./prep_data
python3.7 preprocess.py --dataroot './data/coco' --output './prep_data' --output_flip './prep_data_flip'

if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

python3.7 gen_dataset_info.py bin ./prep_data ./prep_bin.info 192 256
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

python3.7 gen_dataset_info.py bin ./prep_data_flip ./prep_bin_flip.info 192 256
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

source /usr/local/Ascend/ascend-toolkit/set_env.sh
rm -rf result/dumpOutput_device*
./benchmark.${arch} -model_type=vision -device_id=0 -batch_size=1 -om_path=./models/fast_res50_256x192_bs1.om -input_text_path=./prep_bin.info -input_width=192 -input_height=256 -output_binary=True -useDvpp=False
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
mv result/dumpOutput_device0 result/dumpOutput_device0_bs1

./benchmark.${arch} -model_type=vision -device_id=0 -batch_size=1 -om_path=./models/fast_res50_256x192_bs1.om -input_text_path=./prep_bin_flip.info -input_width=192 -input_height=256 -output_binary=True -useDvpp=False
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
mv result/dumpOutput_device0 result/dumpOutput_device0_bs1_flip

python3.7 postprocess.py --dataroot './data/coco' --dump_dir './result/dumpOutput_device0_bs1' --dump_dir_flip './result/dumpOutput_device0_bs1_flip'
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

./benchmark.${arch} -model_type=vision -device_id=0 -batch_size=16 -om_path=./models/fast_res50_256x192_bs16.om -input_text_path=./prep_bin.info -input_width=192 -input_height=256 -output_binary=True -useDvpp=False
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
mv result/dumpOutput_device0 result/dumpOutput_device0_bs16

./benchmark.${arch} -model_type=vision -device_id=0 -batch_size=16 -om_path=./models/fast_res50_256x192_bs16.om -input_text_path=./prep_bin.info -input_width=192 -input_height=256 -output_binary=True -useDvpp=False
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
mv result/dumpOutput_device0 result/dumpOutput_device0_bs16_flip

python3.7 postprocess.py --dataroot './data/coco' --dump_dir './result/dumpOutput_device0_bs16' --dump_dir_flip './result/dumpOutput_device0_bs16_flip'
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi

echo "====performance data===="
python3.7 test/parse.py result/perf_vision_batchsize_1_device_0.txt
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
echo "success"
python3.7 test/parse.py result/perf_vision_batchsize_16_device_0.txt
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
echo "success"
