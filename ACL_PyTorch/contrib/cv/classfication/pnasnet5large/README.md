# pnasnet5large Onnx模型端到端推理指导
-   [1 模型概述](#1-模型概述)
	-   [1.1 论文地址](#11-论文地址)
	-   [1.2 代码地址](#12-代码地址)
-   [2 环境说明](#2-环境说明)
	-   [2.1 深度学习框架](#21-深度学习框架)
	-   [2.2 python第三方库](#22-python第三方库)
-   [3 模型转换](#3-模型转换)
	-   [3.1 pth转onnx模型](#31-pth转onnx模型)
	-   [3.2 onnx转om模型](#32-onnx转om模型)
-   [4 数据集预处理](#4-数据集预处理)
	-   [4.1 数据集获取](#41-数据集获取)
	-   [4.2 数据集预处理](#42-数据集预处理)
	-   [4.3 生成数据集信息文件](#43-生成数据集信息文件)
-   [5 离线推理](#5-离线推理)
	-   [5.1 benchmark工具概述](#51-benchmark工具概述)
	-   [5.2 离线推理](#52-离线推理)
-   [6 精度对比](#6-精度对比)
	-   [6.1 离线推理TopN精度统计](#61-离线推理TopN精度统计)
	-   [6.2 开源TopN精度](#62-开源TopN精度)
	-   [6.3 精度对比](#63-精度对比)
-   [7 性能对比](#7-性能对比)
	-   [7.1 npu性能数据](#71-npu性能数据)
	-   [7.2 T4性能数据](#72-T4性能数据)
	-   [7.3 性能对比](#73-性能对比)

## 1 模型概述

-   **[论文地址](#11-论文地址)**  

-   **[代码地址](#12-代码地址)**  

### 1.1 论文地址
[pnasnet5large论文](https://arxiv.org/abs/1712.00559)  

### 1.2 代码地址
[pnasnet5large代码](https://github.com/rwightman/pytorch-image-models/blob/master/timm/models/pnasnet.py)  
branch:master commit_id:7096b52a613eefb4f6d8107366611c8983478b19

## 2 环境说明

-   **[深度学习框架](#21-深度学习框架)**  

-   **[python第三方库](#22-python第三方库)**  

### 2.1 深度学习框架
```
CANN 5.0.1

torch == 1.8.1
torchvision == 0.9.1
onnx == 1.9.0
```

### 2.2 python第三方库

```
numpy == 1.20.1
Pillow == 8.2.0
opencv-python == 4.5.2.52
timm == 0.4.9
```

**说明：** 
>   X86架构：pytorch，torchvision和onnx可以通过官方下载whl包安装，其它可以通过pip3.7 install 包名 安装
>
>   Arm架构：pytorch，torchvision和onnx可以通过源码编译安装，其它可以通过pip3.7 install 包名 安装

## 3 模型转换

-   **[pth转onnx模型](#31-pth转onnx模型)**  

-   **[onnx转om模型](#32-onnx转om模型)**  

### 3.1 pth转onnx模型

1.pth权重文件  
[pnasnet5large预训练pth权重文件]

由于源代码问题，加载下载好的权重文件会报错，所以选择根据脚本自动下载权重文件

2.pnasnet5large模型代码在timm里，安装timm，arm下需源码安装，参考https://github.com/rwightman/pytorch-image-models
，若安装过程报错请百度解决
```
rm -r pytorch-image-models
git clone https://github.com/rwightman/pytorch-image-models
cd pytorch-image-models
python3.7 setup.py install
cd ..
```
3.编写pth2onnx脚本pnasnet5large_onnx.py

 **说明：**  
>注意目前ATC支持的onnx算子版本为11

4.执行pth2onnx脚本，生成onnx模型文件
```
python3.7 pnasnet5large_onnx.py pnasnet5large.onnx
python3.7 -m onnxsim  --input-shape="1,3,331,331" pnasnet5large.onnx pnasnet5large_sim_bs1.onnx
```

 **模型转换要点：**  
>此模型转换为onnx需要修改开源代码仓代码，将"/usr/local/python3.7.5/lib/python3.7/site-packages/timm/models/pnasnet.py"中349行改为
    model_kwargs = dict(pad_type='', **kwargs)

### 3.2 onnx转om模型

1.设置环境变量
```
source /usr/local/Ascend/ascend-toolkit/set_env.sh
```
2.使用atc将onnx模型转换为om模型文件，工具使用方法可以参考[CANN V100R020C10 开发辅助工具指南 (推理) 01](https://support.huawei.com/enterprise/zh/doc/EDOC1100164868?idPath=23710424%7C251366513%7C22892968%7C251168373)
```
atc --framework=5 --model=./pnasnet5large_sim_bs1.onnx --input_format=NCHW --input_shape="image:1,3,331,331" --output=pnasnet5large_bs1 --log=debug --soc_version=Ascend310

```

## 4 数据集预处理

-   **[数据集获取](#41-数据集获取)**  

-   **[数据集预处理](#42-数据集预处理)**  

-   **[生成数据集信息文件](#43-生成数据集信息文件)**  

### 4.1 数据集获取
该模型使用[ImageNet官网](http://www.image-net.org)的5万张验证集进行测试，图片与标签分别存放在/root/datasets/imagenet/val与/root/datasets/imagenet/val_label.txt。

### 4.2 数据集预处理
1.预处理脚本imagenet_torch_preprocess.py

2.执行预处理脚本，生成数据集预处理后的bin文件
```
python3.7 imagenet_torch_preprocess.py root/datasets/imagenet/val ./prep_dataset
```
### 4.3 生成数据集信息文件
1.生成数据集信息文件脚本get_info.py

2.执行生成数据集信息脚本，生成数据集信息文件
```
python3.7 get_info.py bin ./prep_dataset ./pnasnet5large_prep_bin.info 331 331
```
第一个参数为模型输入的类型，第二个参数为生成的bin文件路径，第三个为输出的info文件，后面为宽高信息
## 5 离线推理

-   **[benchmark工具概述](#51-benchmark工具概述)**  

-   **[离线推理](#52-离线推理)**  

### 5.1 benchmark工具概述

benchmark工具为华为自研的模型推理工具，支持多种模型的离线推理，能够迅速统计出模型在Ascend310上的性能，支持真实数据和纯推理两种模式，配合后处理脚本，可以实现诸多模型的端到端过程，获取工具及使用方法可以参考[CANN V100R020C10 推理benchmark工具用户指南 01](https://support.huawei.com/enterprise/zh/doc/EDOC1100164874?idPath=23710424%7C251366513%7C22892968%7C251168373)
### 5.2 离线推理
1.设置环境变量
```
source /usr/local/Ascend/ascend-toolkit/set_env.sh
```
2.执行离线推理
```
./benchmark.x86_64 -model_type=vision -device_id=0 -batch_size=1 -om_path=pnasnet5large_bs1.om -input_text_path=./pnasnet5large_prep_bin.info -input_width=331 -input_height=331 -output_binary=False -useDvpp=False
```
输出结果默认保存在当前目录result/dumpOutput_device{0}，模型只有一个名为class的输出，shape为bs * 1000，数据类型为FP32，对应1000个分类的预测结果，每个输入对应的输出对应一个_x.bin文件。

## 6 精度对比

-   **[离线推理TopN精度](#61-离线推理TopN精度)**  
-   **[开源TopN精度](#62-开源TopN精度)**  
-   **[精度对比](#63-精度对比)**  

### 6.1 离线推理TopN精度统计

后处理统计TopN精度

调用vision_metric_ImageNet.py脚本推理结果与label比对，可以获得Accuracy Top5数据，结果保存在result_bs1.json中。
```
python3.7 vision_metric_ImageNet.py result/dumpOutput_device0/ root/datasets/imagenet/val_label.txt ./ result_bs1.json
```
第一个为benchmark输出目录，第二个为数据集配套标签，第三个是生成文件的保存目录，第四个是生成的文件名。  
查看输出结果：
```
{"title": "Overall statistical evaluation", "value": [{"key": "Number of images", "value": "50000"}, {"key": "Number of classes", "value": "1000"}, {"key": "Top1 accuracy", "value": "82.62%"}, {"key": "Top2 accuracy", "value": "91.37%"}, {"key": "Top3 accuracy", "value": "94.01%"}, {"key": "Top4 accuracy", "value": "95.32%"}, {"key": "Top5 accuracy", "value": "96.06%"}]}
```

调用vision_metric_ImageNet.py脚本推理结果与label比对，可以获得Accuracy Top5数据，结果保存在result_bs16.json中。
```
python3.7 vision_metric_ImageNet.py result/dumpOutput_device1/ root/datasets/imagenet/val_label.txt ./ result_bs16.json
```
第一个为benchmark输出目录，第二个为数据集配套标签，第三个是生成文件的保存目录，第四个是生成的文件名。  
查看输出结果：
```
{"title": "Overall statistical evaluation", "value": [{"key": "Number of images", "value": "50000"}, {"key": "Number of classes", "value": "1000"}, {"key": "Top1 accuracy", "value": "82.64%"}, {"key": "Top2 accuracy", "value": "91.35%"}, {"key": "Top3 accuracy", "value": "94.02%"}, {"key": "Top4 accuracy", "value": "95.33%"}, {"key": "Top5 accuracy", "value": "96.06%"}]}
```

### 6.2 开源TopN精度
[timm官网精度](https://github.com/rwightman/pytorch-image-models/blob/master/results/results-imagenet.csv)
```
model	         top1	top1_err	top5	top5_err	param_count	img_size	cropt_pct	interpolation
pnasnet5large	82.782	17.218	   96.040	3.960	    86.06	    331	         0.911	     bicubic
```
### 6.3 精度对比
将得到的om离线模型推理TopN精度与该模型github代码仓上公布的精度对比，精度下降在1%范围之内，故精度达标。  
 **精度调试：**  
>没有遇到精度不达标的问题，故不需要进行精度调试

## 7 性能对比

-   **[npu性能数据](#71-npu性能数据)**  
-   **[T4性能数据](#72-T4性能数据)**  
-   **[性能对比](#73-性能对比)**  

### 7.1 npu性能数据
benchmark工具在整个数据集上推理时也会统计性能数据，但是推理整个数据集较慢，如果这么测性能那么整个推理期间需要确保独占device，使用npu-smi info可以查看device是否空闲。也可以使用benchmark纯推理功能测得性能数据，但是由于随机数不能模拟数据分布，纯推理功能测的有些模型性能数据可能不太准，benchmark纯推理功能测性能仅为快速获取大概的性能数据以便调试优化使用，可初步确认benchmark工具在整个数据集上推理时由于device也被其它推理任务使用了导致的性能不准的问题。模型的性能以使用benchmark工具在整个数据集上推理得到bs1与bs16的性能数据为准，对于使用benchmark工具测试的batch4，8，32的性能数据在README.md中如下作记录即可。  
1.benchmark工具在整个数据集上推理获得性能数据  
batch1的性能，benchmark工具在整个数据集上推理后生成result/perf_vision_batchsize_1_device_0.txt：  
```
[e2e] throughputRate: 5.59894, latency: 8.93027e+06
[data read] throughputRate: 5.64275, moduleLatency: 177.219
[preprocess] throughputRate: 5.63929, moduleLatency: 177.327
[infer] throughputRate: 5.6004, Interface throughputRate: 20.5146, moduleLatency: 177.101
[post] throughputRate: 5.6004, moduleLatency: 178.559
```
Interface throughputRate: 20.5146，20.5146x4=82.0584既是batch1 310单卡吞吐率  

batch16的性能，benchmark工具在整个数据集上推理后生成result/perf_vision_batchsize_16_device_1.txt：  
```
[e2e] throughputRate: 18.7451, latency: 2.66737e+06
[data read] throughputRate: 19.2536, moduleLatency: 51.9383
[preprocess] throughputRate: 19.2125, moduleLatency: 52.0493
[infer] throughputRate: 18.7591, Interface throughputRate: 20.01, moduleLatency: 53.0881
[post] throughputRate: 1.17244, moduleLatency: 852.922

```
Interface throughputRate: 20.01，20.01x4=80.04既是batch16 310单卡吞吐率


### 7.2 T4性能数据
在装有T4卡的服务器上测试gpu性能，测试过程请确保卡没有运行其他任务，TensorRT版本：7.2.3.4，cuda版本：11.0，cudnn版本：8.2 
batch1性能：
```
trtexec --onnx=pnasnet5large_sim_bs1.onnx --fp16 --shapes=image:1x3x331x331 --threads
```
gpu T4是4个device并行执行的结果，mean是时延（tensorrt的时延是batch个数据的推理时间），即吞吐率的倒数乘以batch
```
[07/02/2021-02:04:02] [I] GPU Compute
[07/02/2021-02:04:02] [I] min: 11.1588 ms
[07/02/2021-02:04:02] [I] max: 12.4846 ms
[07/02/2021-02:04:02] [I] mean: 11.5547 ms
[07/02/2021-02:04:02] [I] median: 11.4367 ms
[07/02/2021-02:04:02] [I] percentile: 12.4313 ms at 99%
[07/02/2021-02:04:02] [I] total compute time: 3.02734 s
```
batch1 t4单卡吞吐率：1000/(11.5547/1)=86.54487fps  

batch16性能：
```
trtexec --onnx=pnasnet5large_sim_bs16.onnx --fp16 --shapes=image:16x3x224x224 --threads

```
```
[07/03/2021-02:07:56] [I] GPU Compute
[07/03/2021-02:07:56] [I] min: 132.081 ms
[07/03/2021-02:07:56] [I] max: 139.161 ms
[07/03/2021-02:07:56] [I] mean: 134.566 ms
[07/03/2021-02:07:56] [I] median: 133.817 ms
[07/03/2021-02:07:56] [I] percentile: 139.161 ms at 99%
[07/03/2021-02:07:56] [I] total compute time: 3.22957 s
```
batch16 t4单卡吞吐率：1000/(134.566/16)=118.90076fps  


### 7.3 性能对比
batch1：10.6257x4 < 1000/(11.5547/1) 
batch16：20.01x4 < 1000/(134.566/16)
310单个device的吞吐率乘4即单卡吞吐率比T4单卡的吞吐率小，故310性能低于T4性能，性能不达标。  

 **性能优化：**  
>使用autotune与repeat autotune优化前后性能对比
pnasnet5large模型	未任何优化前310（单卡吞吐率）	autotune后310（单卡吞吐率）
bs1	                82.0584fps	                 86.7768fps20
bs16	            79.336fps	                 80.8104
