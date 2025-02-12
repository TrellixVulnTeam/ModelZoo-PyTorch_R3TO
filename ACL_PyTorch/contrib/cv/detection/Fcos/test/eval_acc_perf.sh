#!/bin/bash

datasets_path="/opt/npu/"

for para in $*
do
    if [[ $para == --datasets_path* ]]; then
        datasets_path=`echo ${para#*=}`
    fi
done

arch=`uname -m`
rm -rf ./val2017_bin
python3.7 fcos_pth_preprocess.py --image_src_path=${datasets_path}coco/val2017 --bin_file_path=val2017_bin --model_input_height=800 --model_input_width=1333
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
python3.7 get_info.py bin val2017_bin fcos.info 1333 800
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
chmod +x ben*
source /usr/local/Ascend/ascend-toolkit/set_env.sh
rm -rf result/dumpOutput_device0
./benchmark.${arch}  -model_type=vision -om_path=fcos_bs1.om -device_id=0 -batch_size=1 -input_text_path=fcos.info -input_width=1333 -input_height=800 -useDvpp=false -output_binary=true
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
./benchmark.${arch}  -model_type=vision -om_path=fcos_bs16.om -device_id=1 -batch_size=16 -input_text_path=fcos.info -input_width=1333 -input_height=800 -useDvpp=false -output_binary=true
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
python3.7 get_info.py jpg ${datasets_path}coco/val2017 fcos_jpeg.info
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
echo "====accuracy data===="
python3.7 fcos_pth_postprocess.py --bin_data_path=./result/dumpOutput_device0/ --test_annotation=fcos_jpeg.info --det_results_path=./ret_npuinfer/ --net_out_num=3 --net_input_height=800 --net_input_width=1333 --ifShowDetObj --annotations_path ${datasets_path}coco/annotations
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
python3.7 fcos_pth_postprocess.py --bin_data_path=./result/dumpOutput_device1/ --test_annotation=fcos_jpeg.info --det_results_path=./ret_npuinfer/ --net_out_num=3 --net_input_height=800 --net_input_width=1333 --ifShowDetObj --annotations_path ${datasets_path}coco/annotations
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
python3.7 test/parse.py result/perf_vision_batchsize_16_device_1.txt
if [ $? != 0 ]; then
    echo "fail!"
    exit -1
fi
echo "success"