rm -rf GloRe.onnx
python3.7 GloRe_pth2onnx.py GloRe.pth GloRe.onnx
rm -rf GloRe_bs1.om GloRe_bs16.om
source /usr/local/Ascend/ascend-toolkit/set_env.sh
#${chip_name}由“npu-smi info”命令查看处理器芯片得到
atc --framework=5 --model=GloRe.onnx --output=GloRe_bs1 --input_format=NCHW --input_shape="image:1,3,8,224,224" --log=error --soc_version=Ascend${chip_name}
atc --framework=5 --model=GloRe.onnx --output=GloRe_bs16 --input_format=NCHW --input_shape="image:16,3,8,224,224" --log=error --soc_version=Ascend${chip_name}
if [ -f "GloRe_bs1.om" ]; then
    echo "GloRe_bs1.om success"
else
    echo "fail!"
fi
if [ -f "GloRe_bs16.om" ]; then
    echo "GloRe_bs16.om success"
else
    echo "fail!"
fi
