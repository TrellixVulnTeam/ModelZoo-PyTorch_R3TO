cd ../
source /usr/local/Ascend/ascend-toolkit/set_env.sh
python3.7 pyramidbox_pth2onnx.py ./pyramidbox_1000.onnx ./pyramidbox_120000_99.02.pth
