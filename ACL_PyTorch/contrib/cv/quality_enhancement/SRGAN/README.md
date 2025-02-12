# SRGAN模型-推理指导


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

基于PyTorch实现SRGAN生成对抗网络的照片级真实感单图像超分辨率。



- 参考实现：

  ```
  url= https://github.com/leftthomas/SRGAN
  branch=master 
  commit_id=961e557de8eaeec636fbe1f4276f5f623b5985d4
  ```


  通过Git获取对应commit\_id的代码方法如下：

  ```
  git clone {repository_url}    # 克隆仓库的代码
  cd {repository_name}    # 切换到模型的代码仓目录
  git checkout  {branch}    # 切换到对应分支
  git reset --hard ｛commit_id｝     # 代码设置到对应的commit_id    （可选）
  cd ｛code_path｝    # 切换到模型代码所在路径，若仓库下只有该模型，则无需切换
  ```


## 输入输出数据<a name="section540883920406"></a>

- 输入数据

  | 输入数据 | 数据类型 | 大小                      | 数据排布格式 |
  | -------- | -------- | ------------------------- | ------------ |
  | input    | FLOAT32 | 1 x 3 x 140 x 140 | NCHW         |


- 输出数据

  | 输出数据 | 大小     | 数据类型 | 数据排布格式 |
  | -------- | -------- | -------- | ------------ |
  | output1  | 1 x 3 x 280 x 280 | FLOAT32  | NCHW           |



# 推理环境准备\[所有版本\]<a name="ZH-CN_TOPIC_0000001126281702"></a>


- 该模型需要以下插件与驱动

  **表 1**  版本配套表

| 配套                                                         | 版本    | 环境准备指导                                                 |
| ------------------------------------------------------------ | ------- | ------------------------------------------------------------ |
| 固件与驱动                                                   | 1.0.15  | [Pytorch框架推理环境准备](https://www.hiascend.com/document/detail/zh/ModelZoo/pytorchframework/pies) |
| CANN                                                         | 5.1.RC2 | -                                                            |
| Python                                                       | 3.7.5   | -                                                            |
| PyTorch                                                      | 1.6.0   | -                                                            |
| 说明：Atlas 300I Duo 推理卡请以CANN版本选择实际固件与驱动版本。 | \       | \                                                            |


# 快速上手<a name="ZH-CN_TOPIC_0000001126281700"></a>



1. 安装依赖。

   ```
   pip install -r requirements.txt
   ```


## 准备数据集<a name="section183221994411"></a>

1. 获取原始数据集。（解压命令参考tar –xvf  \*.tar与 unzip \*.zip）
  本模型要求在Set5的数据集上完成测试，将数据集放置在源码目录下test文件夹，文件夹若无请自行创建，Set5数据集只有五张图片，请用户自行获取数据集。


2. 数据预处理。

   数据预处理将原始数据集转换为模型输入的数据。

   执行“srgan_preprocess.py”脚本，完成预处理。

   ```
   python3.7 srgan_preprocess.py --src_path=./test/SRF_2 --save_path=./preprocess_data
   ```

    --src_path：原始数据验证集（.jpeg）所在路径。

    --save_path：输出的二进制文件（.bin）所在路径。

  每个图像对应生成一个二进制文件。运行成功后，在当前目录下生成preprocess_data二进制文件夹。
 


## 模型推理<a name="section741711594517"></a>

1. 模型转换。

   使用PyTorch将模型权重文件.pth转换为.onnx文件，再使用ATC工具将.onnx文件转为离线推理模型文件.om文件。

   1. 获取权重文件。

       请用户自行获取

   2. 导出onnx文件。

      1. 使用srgan_pth2onnx.py导出onnx文件。

         运行srgan_pth2onnx.py脚本。

         ```
         python3.7 srgan_pth2onnx.py ./netG_best.pth batch
         ```

         batch是输入的batch大小,以下输入都为1, 获得srgan_bs1.onnx文件。

      2. 优化ONNX文件。
         运行eidt_onnx.py脚本。

         ```
         python3.7 eidt_onnx.py ./srgan_bs1.onnx batch
         ```

         获得srgan_fix_bs1.onnx文件。

   3. 使用ATC工具将ONNX模型转OM模型。

      1. 配置环境变量。

         ```
          source /usr/local/Ascend/ascend-toolkit/set_env.sh
         ```

         > **说明：** 
         >该脚本中环境变量仅供参考，请以实际安装环境配置环境变量。详细介绍请参见《[CANN 开发辅助工具指南 \(推理\)](https://support.huawei.com/enterprise/zh/ascend-computing/cann-pid-251168373?category=developer-documents&subcategory=auxiliary-development-tools)》。

      2. 执行命令查看芯片名称。

         ```
         npu-smi info
         ```
         
         ```
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
         atc --model=./srgan_fix_bs1.onnx --framework=5 --output=srgan_dynamic_bs1 --input_format=NCHW --input_shape="lrImage:1,3,-1,-1" --dynamic_image_size="140,140;256,256;172,114;128,128;144,144" --log=info --soc_version=Ascend{chip_name}
         ```

         - 参数说明：

           -   --model：为ONNX模型文件。
           -   --framework：5代表ONNX模型。
           -   --output：输出的OM模型。
           -   --input\_format：输入数据的格式。
           -   --input\_shape：输入数据的shape。
           -   --log：日志级别。
           -   --soc\_version：处理器型号。
           

           运行成功后生成srgan_dynamic_bs1.om模型文件。



2. 开始推理验证。

    a.  使用ais-infer工具进行推理
        ais-infer工具获取及使用方式请点击查看[[ais_infer推理工具使用文档](https://gitee.com/ascend/tools/tree/master/ais-bench_workload/tool/ais_infer)]
       
    b.  执行推理。

         bash estimate_per.sh --batch_size=1
    

    参数说明：
        batch_size：输入模型的batch大小。
        推理后的输出默认在当前目录result下。
        脚本estimate_per.sh中调用了ais-infer工具进行推理，请根据实际情况调整工具的路径

    说明：
        执行ais-infer工具请选择与运行环境架构相同的命令。

    c.  精度验证。

    调用“srgan_om_infer.py ”完成最终的精度验证，在运行之前需要手动在当前目录下创建名为“infer_om_res”的结果输出文件夹。

    
        python3.7 srgan_om_infer.py --data_path=./test/SRF_2/data --target_path=./test/SRF_2/target --result_path=./result
    
    
    --data_path：测试数据集中的data路径。
    --target_path：测试数据集中的target路径。
    --result_path：推理结果路径。

# 模型推理性能&精度<a name="ZH-CN_TOPIC_0000001172201573"></a>

精度

||PSNR|SSIM|
|--|--|--|
|310p精度|33.4392|0.9308|
|310精度|33.4392|0.9308|
|t4精度|33.4392|0.9308|

性能

| Throughput  | 310P| 310 | T4 | 310P /310 | 310P /T4 |
|---|---|---|---|---|---|
| bs1 |  358.7048      | 210.838	  | 207.38	  | 1.701329	    |1.729698  |
| bs4 |  347.9085      | 213.264	  | 210.2048      | 1.631351	    |1.655093 |
| bs8 |  354.1387      | 213.336	  | 211.90133     | 1.660004	    |1.671243 |
| bs16|  355.3107      | 208.528	  | 257.6858      | 1.703899	    |1.378852 |
| bs32|  358.5532      | 208.864	  | 284.297	  | 1.716683	    |1.261192  |
| bs64|  361.4626      | 209.024	  | 282.6368      | 1.729288	    |1.278894 |
| 最优bs| 361.4626     | 213.336	  | 284.297	  | 1.694334	    |1.271426 |