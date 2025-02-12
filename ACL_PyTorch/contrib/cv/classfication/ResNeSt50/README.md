# ResNeSt50模型-推理指导


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

ResNeSt 的全称是：Split-Attention Networks，引入了Split-Attention模块。借鉴了：Multi-path 和 Feature-map Attention思想。在 ImageNet 上实现了81.13％ top-1 准确率。




- 参考实现：

  ```
  url=https://github.com/zhanghang1989/ResNeSt
  branch=master
  commit_id=1dfb3e8867e2ece1c28a65c9db1cded2818a2031
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
  | input    | RGB_FP32 | batchsize x 3 x 224 x 224 | NCHW         |


- 输出数据

  | 输出数据 | 大小     | 数据类型 | 数据排布格式 |
  | -------- | -------- | -------- | ------------ |
  | output1  | batchsize x 1000 | FLOAT32  | ND           |


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

# 快速上手<a name="ZH-CN_TOPIC_0000001126281700"></a>



1. 安装依赖。

   ```
   pip3 install -r requirment.txt
   ```


## 准备数据集<a name="section183221994411"></a>

1. 获取原始数据集。（解压命令参考tar –xvf  \*.tar与 unzip \*.zip）

本模型支持ImageNet 50000张图片的验证集。以ILSVRC2012为例，请用户需自行获取ILSVRC2012数据集，上传数据集到服务器任意目录并解压（如：/root/datasets/imagenet/val/）。本模型将使用到ILSVRC2012_img_val.tar验证集及ILSVRC2012_devkit_t12.gz中的val_label.txt数据标签。[ImageNet官网](http://www.image-net.org/) 

使用5万张验证集进行测试，图片与标签分别存放在/root/datasets/imagenet/val与/root/datasets/imagenet/val_label.txt。


2. 数据预处理。\(请拆分sh脚本，将命令分开填写\)

   数据预处理将原始数据集转换为模型输入的数据。

   执行imagenet_torch_preprocess.py脚本，完成预处理。
   
   ```
   python3.7 imagenet_torch_preprocess.py resnet /root/datasets/imagenet/val/ ./prep_dataset 
   ```
   预处理结果存放在prep_dataset里

   

## 模型推理<a name="section741711594517"></a>

1. 模型转换。

   使用PyTorch将模型权重文件.pth转换为.onnx文件，再使用ATC工具将.onnx文件转为离线推理模型文件.om文件。

   1. 获取权重文件。

       [ResNeSt预训练pth权重文件](https://github.com/zhanghang1989/ResNeSt/releases/download/weights_step1/resnest50-528c19ca.pth)

        ```
           wget https://github.com/zhanghang1989/ResNeSt/releases/download/weights_step1/resnest50-528c19ca.pth
        ```

   2. 导出onnx文件。

      1. 使用resnest_pth2onnx.py导出onnx文件。

         运行resnest_pth2onnx.py脚本。
         ```
         python3.7 resnest_pth2onnx.py --source="./resnest50.pth" --target="resnest50.onnx"
         ```
         --source：权重文件（.path）所在路径。

         --target：输出的onnx文件（.onnx）所在路径。
        获得“resnest50.onnx”文件。

      2. 优化ONNX文件。

         ```
         python3.7 -m onnxsim --input-shape="1,3,224,224" --dynamic-input-shape resnest50.onnx resnest50_sim.onnx
         ```

         获得resnest50_sim.onnx文件。

     3. 使用ATC工具将ONNX模型转OM模型。

      1. 配置环境变量。
         ```
          source  /usr/local/Ascend/ascend-toolkit/set_env.sh
         ```

         > **说明：** 
         >该脚本中环境变量仅供参考，请以实际安装环境配置环境变量。详细介绍请参见《[CANN 开发辅助工具指南 \(推理\)](https://support.huawei.com/enterprise/zh/ascend-computing/cann-pid-251168373?category=developer-documents&subcategory=auxiliary-development-tools)》。

      2. 执行命令查看芯片名称（$\{chip\_name\}）。

         ```
         npu-smi info
         #该设备芯片名为Ascend310P3 （自行替换）
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
         atc --framework=5 --model=./resnest50_sim.onnx --output=resnest50_b1 --input_format=NCHW --input_shape="actual_input_1:1,3,224,224" --log=debug --soc_version=Ascend${chip_name} --input_fp16_nodes="actual_input_1"
         ```

         - 参数说明：

           -   --model：为ONNX模型文件。
           -   --framework：5代表ONNX模型。
           -   --output：输出的OM模型。
           -   --input\_format：输入数据的格式。
           -   --input\_shape：输入数据的shape。
           -   --log：日志级别。
           -   --soc\_version：处理器型号。
          
           运行成功后生成resnest50_b1 模型文件。



2. 开始推理验证。

  使用ais-infer工具进行推理。

  a.  执行推理。

    ```
     python3 ./tools/ais-bench_workload/tool/ais_infer/ais_infer.py --model ./new_resnest50_b1.om --input ./prep_dataset/ --output ./result/ --outfmt TXT --batchsize 1
    ```

        - 参数说明：
        - outfmt：推理结果数据类型。
        - model：om文件路径。
        
		

        推理后的输出默认在当前目录result下。

        >**说明：** 
        >执行ais-infer工具请选择与运行环境架构相同的命令。参数详情请参见：

    https://gitee.com/ascend/tools/tree/master/ais-bench_workload/tool/ais_infer
c.  精度验证。

    调用脚本与数据集标签val\_label.txt比对，可以获得Accuracy数据，结果保存在result.json中。

    ```
     python3 postprocess.py --result_path=./lcmout/2022_xx_xx-xx_xx_xx/sumary.json    
    ```
    --result_path：推理结果中的json文件
 

# 模型推理性能&精度<a name="ZH-CN_TOPIC_0000001172201573"></a>

调用ACL接口推理计算，性能参考下列数据。

性能：



| batchsize | 1      | 4    | 8       | 16      | 32      | 64      |
|-----------|--------|------|---------|---------|---------|---------|
| 310       | 780    | 1032 | 1144    | 1224    | 1208    | 1148    |
| 310P      | 817.86 | 1798 | 1642.23 | 1459.38 | 1331.22 | 1297.77 |
| T4        | 199    | 625  | 667     | 605     | 667     | 1174    |


精度：

|      | top1_acc |
|------|----------|
| 310  | 80.83%   |
| 310P | 80.95%   |


