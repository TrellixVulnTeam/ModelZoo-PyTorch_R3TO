# SSD-ResNet34模型-推理指导


- [概述](#ZH-CN_TOPIC_0000001172161501)

- [推理环境准备](#ZH-CN_TOPIC_0000001126281702)

- [快速上手](#ZH-CN_TOPIC_0000001126281700)

  - [获取源码](#section4622531142816)
  - [准备数据集](#section183221994411)
  - [模型推理](#section741711594517)

- [模型推理性能](#ZH-CN_TOPIC_0000001172201573)

- [配套环境](#ZH-CN_TOPIC_0000001126121892)

  ******




# 概述<a name="ZH-CN_TOPIC_0000001172161501"></a>

SSD模型是用于图像检测的模型，通过基于Resnet34残差卷积网络(基础网络)，并向网络添加辅助结构，产生具有多尺度特征图的预测。在多个尺度的特征图中使用不同的默认框形状，可以有效地离散地输出不同大小的框，面对不同的目标可以有效地检测到，并且还可以对目标进行识别。


- 参考实现：

  ```
  url=https://github.com/mlcommons/training_results_v0.7
  branch=master
  commit_id=elc4b963b6a4ee8fbd40fc5cd9edb9789a2982de
  model_name=ssd
  ```

  通过Git获取对应commit\_id的代码方法如下：

  ```
  git clone {repository_url}        # 克隆仓库的代码
  cd {repository_name}              # 切换到模型的代码仓目录
  git checkout {branch/tag}         # 切换到对应分支
  git reset --hard {commit_id}      # 代码设置到对应的commit_id（可选）
  cd {code_path}                    # 切换到模型代码所在路径，若仓库下只有该模型，则无需切换
  ```


## 输入输出数据<a name="section540883920406"></a>

- 输入数据

  | 输入数据 | 数据类型 | 大小                      | 数据排布格式 |
  | -------- | -------- | ------------------------- | ------------ |
  | input    | RGB_FP32 | batchsize x 3 x 300 x 300 | NCHW         |


- 输出数据

  | 输出数据 | 大小     | 数据类型 | 数据排布格式 |
  | -------- | -------- | -------- | ------------ |
  | ploc  | Batchsize x 4 x 8732 | FLOAT32  | ND           |
  | plabel  | Batchsize x 81 x 8732 | FLOAT32  | ND           |


# 推理环境准备\[所有版本\]<a name="ZH-CN_TOPIC_0000001126281702"></a>

- 该模型需要以下插件与驱动

  **表 1**  版本配套表

| 配套                                                         | 版本    | 环境准备指导                                                 |
| ------------------------------------------------------------ | ------- | ------------------------------------------------------------ |
| 固件与驱动                                                   | 1.0.15  | [Pytorch框架推理环境准备](https://www.hiascend.com/document/detail/zh/ModelZoo/pytorchframework/pies) |
| CANN                                                         | 5.1.RC2 | -                                                            |
| Python                                                       | 3.7.5   | -                                                            |
| PyTorch                                                      | 1.5.0   | -                                                            |
| 说明：Atlas 300I Duo 推理卡请以CANN版本选择实际固件与驱动版本。 | \       | \                                                            |

## 获取源码<a name="section4622531142816"></a>

1. 获取源码。

   ```
   git clone https://github.com/mlcommons/training_results_v0.7.git
   cd training_results_v0.7/NVIDIA/benchmarks/ssd/implementations/pytorch/ 
   patch -p1 <../../../../../../ssd.patch       # 通过补丁修改仓库代码
   mv * ../../../../../../../SSD-Resnet34/      # 移动到模型所在路径
   ```

2. 安装依赖。
   1. 获取昇腾版本工具安装包
   - 通过 wget 下载
   ```
   获取torch-1.5.0+ascend.post3.20210930-cp37-cp37m-linux_x86_64.whl

   wget https://ascend-pytorch-release.obs.cn-north-4.myhuaweicloud.com/run_pkg/20211018_FrameworkPTAdapter2.0.T308/torch-1.5.0%2Bascend.post3.20210930-cp37-cp37m-linux_x86_64.whl

   获取tensor_fused_plugin-0.1+ascend-cp37-cp37m-linux_x86_64.whl

   wget https://ascend-pytorch-release.obs.cn-north-4.myhuaweicloud.com/run_pkg/20210423_TR5/whl_0423/tensor_fused_plugin-0.1%2Bascend-cp37-cp37m-linux_x86_64.whl

   获取apex-0.1+ascend.20210930-cp37-cp37m-linux_x86_64.whl

   wget https://ascend-pytorch-release.obs.cn-north-4.myhuaweicloud.com/run_pkg/20211018_FrameworkPTAdapter2.0.T308/apex-0.1%2Bascend.20210930-cp37-cp37m-linux_x86_64.whl
   ```
   - 若安装包无法通过wget下载，则可通过下述百度云网盘下载
   ```
   链接：https://pan.baidu.com/s/1xH3ZSP63NRukAPMlI4ePNw 
   提取码：rcof
   ```
   1. 安装环境
   ```
   pip3 install -r requirment.txt
   git clone https://github.com/mlperf/logging.git mlperf-logging
   pip install -e mlperf-logging
   pip install torch-1.5.0+ascend.post3.20210930-cp37-cp37m-linux_x86_64.whl
   pip install apex-0.1+ascend.20210930-cp37-cp37m-linux_x86_64.whl
   pip install tensor_fused_plugin-0.1+ascend-cp37-cp37m-linux_x86_64.whl
   ```


## 准备数据集<a name="section183221994411"></a>

1. 获取原始数据集。（解压命令参考tar –xvf  \*.tar与 unzip \*.zip）

   本模型支持coco2017的val2017验证数据集，里面有5000张图片。用户可自行获取coco2017数据集中的annotations和val2017，上传数据集到服务器任意目录并解压（如：/home/HwHiAiUser/dataset），本模型将使用到coco2017数据集中的验证集及其标签文件instances_val2017.json, bbox_only_instances_val2017.json，标签文件bbox_only_instances_val2017.json是将coco2017中的原标签文件instances_val2017.json经过处理所得。
   数据目录结构请参考：
   ```
    ├── coco
    │    ├── val2017   
    │    ├── annotations
    │         ├──instances_val2017.json
    │         ├──bbox_only_instances_val2017.json
    ```
    
2. 数据预处理。

    说明：只支持bin文件推理

   数据预处理将原始数据集转换为模型输入的数据。

   执行prepare-json.py脚本，得到bbox_only_instances_val2017.json文件

   ```
   python3 prepare-json.py --keep-keys ${data_path}/coco/annotations/instances_val2017.json ${data_path}/coco/annotations/bbox_only_instances_val2017.json
   ```

   执行ssd_preprocess.py脚本，完成预处理。

   ```
   python3 ssd_preprocess.py --data=${data_path}/coco --bin-output=./ssd_bin
   ```
   - 参数说明：
      -  --data：数据集路径。
      -  --bin-output：预处理后的数据文件的相对路径。



## 模型推理<a name="section741711594517"></a>

1. 模型转换。

   使用PyTorch将模型权重文件.pth转换为.onnx文件，再使用ATC工具将.onnx文件转为离线推理模型文件.om文件。

   1. 获取权重文件。

    从源码包中获取权重文件：“iter_183250.pt”和“resnet34-333f7ec4.pth”，对于pth权重文件，统一放在新建models文件夹下。

   2. 导出onnx文件。

      1. 使用ssd_pth2onnx.py导出onnx文件。
        使用“resnet34-333f7ec4.pth”和“iter_183250.pt”导出onnx文件。
        运行“ssd_pth2onnx.py”脚本。

         ```
            python3 ssd_pth2onnx.py --bs=1 --resnet34-model=./models/resnet34-333f7ec4.pth --pth-path=./models/iter_183250.pt --onnx-path=./ssd_bs1.onnx

         ```
         - 参数说明：
            -  --resnet34-model : resnet34 骨干网络权重路径
            -  --pth-path: SSD-ResNet34 权重路径
            -  --onnx-path: onnx文件路径

         获得ssd_bs1.onnx文件（默认为动态导出）。

   3. 使用ATC工具将ONNX模型转OM模型。

      1. 配置环境变量。

         ```
          source /usr/local/Ascend/ascend-toolkit/set_env.sh
         ```

         > **说明：** 
         >该脚本中环境变量仅供参考，请以实际安装环境配置环境变量。详细介绍请参见《[CANN 开发辅助工具指南 \(推理\)](https://support.huawei.com/enterprise/zh/ascend-computing/cann-pid-251168373?category=developer-documents&subcategory=auxiliary-development-tools)》。

      2. 执行命令查看芯片名称（Ascend310P3）。

         ```
         npu-smi info
         #该设备芯片名为Ascend310P3
         回显如下：
         +-------------------+-----------------+------------------------------------------------------+
         | NPU     Name      | Health          | Power(W)     Temp(C)           Hugepages-Usage(page) |
         | Chip    Device    | Bus-Id          | AICore(%)    Memory-Usage(MB)                        |
         +===================+=================+======================================================+
         | 0       310P3     | OK              | 15.8         42                0    / 0              |
         | 0       0         | 0000:82:00.0    | 0            1074 / 21534                            |
         +===================+=================+======================================================+
         | 1       310P3     | OK              | 15.4         43                0    / 0              |
         | 0       1         | 0000:89:00.0    | 0            1070 / 21534                            |
         +===================+=================+======================================================+
         ```

      3. 执行ATC命令。

         ```
            atc --framework=5 --model=./ssd_bs1.onnx --output=./ssd_bs1 --input_format=NCHW --input_shape="image:1,3,300,300" --log=error --soc_version=Ascend${ChipName}
         ```

         - 参数说明：

           -   --model：为ONNX模型文件。
           -   --framework：5代表ONNX模型。
           -   --output：输出的OM模型。
           -   --input\_format：输入数据的格式。
           -   --input\_shape：输入数据的shape。
           -   --log：日志级别。
           -   --soc\_version：处理器型号。
           -   --insert\_op\_conf=aipp\_resnet34.config:  AIPP插入节点，通过config文件配置算子信息，功能包括图片色域转换、裁剪、归一化，主要用于处理原图输入数据，常与DVPP配合使用，详见下文数据预处理。

           运行成功后生成"ssd_bs1.om"模型文件。



2. 开始推理验证。

    1. 使用ais-infer工具进行推理。

      ais-infer工具获取及使用方式请点击查看[[ais_infer 推理工具使用文档](https://gitee.com/ascend/tools/tree/master/ais-bench_workload/tool/ais_infer)]

    2.  执行推理。


    ```
        python ais_infer.py --model ${om_path}/ssd_bs1.om  --input /path/to/ssd_bin/ --output ${out_path} --batchsize ${n}
    ```
    -   参数说明：

        -   --model：为.OM模型文件路径。
        -   --input：为输入图片导出到二进制文件路径。
        -   --output：模型推理结果存放的路径。
        -   --batchsize：输入batch size

        推理后的输出在 ${out_path}目录下。

        >**说明：** 
        >执行ais-infer工具请选择与运行环境架构相同的命令。参数详情请参见。

    3. 精度验证。

    调用“ssd_postprocess.py”评测模型的精度。

    ```
        python ssd_postprocess.py --data=${data_path}/coco --bin-input=${output_path}

    ```
    -   参数说明：
        -   --bin-input：生成推理结果所在路径。
        -   --data：数据集路径。


# 模型推理性能&精度<a name="ZH-CN_TOPIC_0000001172201573"></a>

调用ACL接口推理计算，性能参考下列数据。

| Precision | mAP   |
|-----------|-------|
| 310精度   | 23.0% |
| 310P精度  | 23.0% |


| Throughput | 310 | 310P | T4 | 310P/310 | 310P/T4 |
|------------|-----|------|----|----------|---------|
| bs1        | 711.356    |  925.091    | 483.38   |     1.30     |    1.913     |
| bs4        |  825.516   |  1302.783    | 666.23   |     1.578     |     1.9554    |
| bs8        |   849.156  |  1406.351   | 735.327   |     1.656     |     1.912   |
| bs16       |  862.468   |   1358.895   |  774.908  |    1.575      |    1.753     |
| bs32       |   812.368  |   1370.644   |  784.2675  |      1.687    |    1.747     |
| bs64       | 810.368    |   914.474   |  823.365  |   1.060       |   1.11      |
| 最优batch        |  862.468   |   1406.351   | 823.365   |    1.630      |    1.708     |