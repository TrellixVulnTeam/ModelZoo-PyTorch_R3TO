#!/bin/bash

source /usr/local/Ascend/ascend-toolkit/set_env.sh

./msame --model "./StarGAN_bs16.om"  --input "./bin/img",'./bin/attr' --output "./output_bs16" --outfmt TXT > StarGAN_bs16.log

DIR="output_bs16"
mkdir $DIR

if [ "$(ls -A $DIR)" ]; then
  echo "Turn to txt success!"
  echo "Begin to infer!"
else
  echo "Turn to txt fail!"
  exit -1
fi

perf_str=`grep "Inference average time : " StarGAN_bs16.log`
if [ -n "$perf_str" ]; then
    perf_num=`echo $perf_str | awk -F ' ' '{print $5}'`
    echo "(310 bs16) Inference average time:" $perf_num "ms"
else
  echo "fail!"
  exit -1
fi

awk 'BEGIN{printf "(310 bs16) FPS:%.3f\n", 1000*1/('$perf_num'/64)}'