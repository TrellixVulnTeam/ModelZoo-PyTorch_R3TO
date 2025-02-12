# Xception_ID1777_for_PyTorch

- [概述](概述.md)
- [准备训练环境](准备训练环境.md)
- [开始训练](开始训练.md)
- [训练结果展示](训练结果展示.md)
- [版本说明](版本说明.md)

# 概述

## 简述

Xception即Extreme version of Inception。Xception是google继Inception后提出的对InceptionV3的另一种改进，主要是采用深度可分离卷积（depth wise separable convolution）来替换原来InceptionV3中的卷积操作。在基本不增加网络复杂度的前提下提高了模型的效果，但网络复杂度没有大幅降低。原因是作者加宽了网络，使得参数数量和Inception v3差不多。因此Xception主要目的不在于模型压缩，而是提高性能。

- 参考实现：

  ```
  url=https://github.com/kwotsin/TensorFlow-Xception
  commit_id=c42ad8cab40733f9150711be3537243278612b22
  ```
- 适配昇腾 AI 处理器的实现：

  ```
  url=https://gitee.com/ascend/ModelZoo-PyTorch.git 
  code_path=PyTorch/contrib/cv/classification
  ```
- 通过Git获取代码方法如下：

  ```
  git clone {url}       # 克隆仓库的代码
  cd {code_path}        # 切换到模型代码所在路径，若仓库下只有该模型，则无需切换
  ```
- 通过单击“立即下载”，下载源码包。

# 准备训练环境

## 准备环境

- 当前模型支持的固件与驱动、 CANN 以及 PyTorch 如下表所示。

  **表 1**  版本配套表

  | 配套       | 版本                                                                      |
  | ---------- | ------------------------------------------------------------------------- |
  | 固件与驱动 | [5.1.RC2](https://www.hiascend.com/hardware/firmware-drivers?tag=commercial) |
  | CANN       | [5.1.RC2](https://www.hiascend.com/software/cann/commercial?version=5.1.RC2) |
  | PyTorch    | [1.8.1](https://gitee.com/ascend/pytorch/tree/master/)                       |
- 环境准备指导。

  请参考《[Pytorch框架训练环境准备](https://www.hiascend.com/document/detail/zh/ModelZoo/pytorchframework/ptes)》。
- 安装依赖。

  ```
  pip install -r requirements.txt
  ```

## 准备数据集

1. 获取数据集。

   用户自行获取原始数据集，可选用的开源数据集包括ImageNet2012，CIFAR-10等，将数据集上传到服务器任意路径下并解压。

   以ImageNet2012数据集为例，数据集目录结构参考如下所示。

   ```
   ├── ImageNet2012
         ├──train
              ├──类别1
                    │──图片1
                    │──图片2
                    │   ...   
              ├──类别2
                    │──图片1
                    │──图片2
                    │   ...   
              ├──...   
         ├──val  
              ├──类别1
                    │──图片1
                    │──图片2
                    │   ...   
              ├──类别2
                    │──图片1
                    │──图片2
                    │   ...  
   ```

   > **说明：**
   > 该数据集的训练过程脚本只作为一种参考示例。
   >

# 开始训练

## 训练模型

1. 进入解压后的源码包根目录。

   ```
   cd /${模型文件夹名称} 
   ```
2. 运行训练脚本。

   该模型支持单机单卡训练和单机8卡训练。

   - 单机单卡训练

     启动单卡训练。

     ```
     bash ./test/train_full_1p.sh --data_path=/data/xxx/  
     ```
   - 单机8卡训练

     启动8卡训练。

     ```
     bash ./test/train_full_8p.sh --data_path=/data/xxx/   
     ```

   --data\_path参数填写数据集路径。

   模型训练脚本参数说明如下。

   ```
   --data_path                         //数据集路径 
   --workers                           //加载数据进程数   
   --train_epochs                      //重复训练次数 
   --batch_size                        //训练批次大小 
   --learning-rate                     //初始学习率，默认：0.1 
   --mom                          	    //动量，默认：0.9 
   --multiprocessing-distributed       //是否使用多卡训练 
   --weight-decay                      //权重衰减 
   --amp                               //是否使用混合精度 
   --loss-scale                        //混合精度lossscale大小,默认”dynamic”
   --opt-level                         //混合精度类型,默认”O2”
   ```

   训练完成后，权重文件保存在当前路径下，并输出模型训练精度和性能信息。

# 训练结果展示

**表 2**  训练结果展示表

| Acc@1 |   FPS   | Npu_nums | Epochs | AMP_Type | Torch |
| :----: | :-----: | :------: | :----: | :------: | :---: |
|   -   |   492   |    1    |  150  |    O2    |  1.5  |
| 78.86 |  1420  |    8    |  150  |    O2    |  1.5  |
|   -   | 333.183 |    1    |  150  |    O2    |  1.8  |
| 78.814 | 2324.3 |    8    |  100  |    O2    |  1.8  |

# 版本说明

## 变更

2022.09.15：更新pytorch，重新发布。

## 已知问题

无。