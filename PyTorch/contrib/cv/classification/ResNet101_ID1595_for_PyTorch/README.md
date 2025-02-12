# ResNet101 for PyTorch

-   [概述](#概述)
-   [准备训练环境](#准备训练环境)
-   [开始训练](#开始训练)
-   [训练结果展示](#训练结果展示)
-   [版本说明](#版本说明)

# 概述

## 简述

ResNet是ImageNet竞赛中分类问题效果较好的网络，它引入了残差学习的概念，通过增加直连通道来保护信息的完整性，解决信息丢失、梯度消失、梯度爆炸等问题，让很深的网络也得以训练。ResNet有不同的网络层数，常用的有18-layer、34-layer、50-layer、101-layer、152-layer。

ResNet101的含义是指网络中有101-layer，由于兼顾了速度与精度，目前较为常用。

- 参考实现：

  ```
  url=https://github.com/pytorch/examples.git
  commit_id=507493d7b5fab51d55af88c5df9eadceb144fb67
  ```

- 适配昇腾 AI 处理器的实现：

    ```
    url=https://gitee.com/ascend/ModelZoo-PyTorch.git
    code_path=PyTorch/contrib/cv/classification
    ```

- 通过Git获取代码方法如下：
  
    ```
    git clone {url}        # 克隆仓库的代码   
    cd {code_path}         # 切换到模型代码所在路径，若仓库下只有该模型，则无需切换
    ```


- 通过单击“立即下载”，下载源码包。

# 准备训练环境

- 当前模型支持的固件与驱动、 CANN 以及 PyTorch 如下表所示。

  **表 1**  版本配套表

  | 配套       | 版本                                                         |
  | ---------- | ------------------------------------------------------------ |
  | 固件与驱动  | [5.1.RC2](https://www.hiascend.com/hardware/firmware-drivers?tag=commercial)  |
  | CANN       | [5.1.RC2](https://www.hiascend.com/software/cann/commercial?version=5.1.RC2) |
  | PyTorch    | [1.8.1](https://gitee.com/ascend/pytorch/tree/master/)      |

- 环境准备指导。

  请参考《[Pytorch框架训练环境准备](https://www.hiascend.com/document/detail/zh/ModelZoo/pytorchframework/ptes)》。
  
- 安装依赖。

  ```
  pip install -r requirements.txt
  ```

## 准备数据集

1. 获取数据集。

   用户自行获取原始数据集，可选用的开源数据集包括ImageNet2012，CIFAR-10等，将数据集上传到服务器任意路径下并解压。
   数据集目录结构如下所示：

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
     bash ./test/train_full_1p.sh --data_path=xxx
     ```

   - 单机8卡训练

     启动8卡训练。

     ```
     bash ./test/train_full_8p.sh --data_path=xxx
     ```

   --data\_path参数填写数据集根目录

   模型训练脚本参数说明如下。
    ```
    --addr                              //主机地址
    --workers                           //加载数据进程数 
    --learning-rate                     //初始学习率
    --mom                               //动量，默认：0.9
    --weight-decay                      //权重衰减，默认：0.0001
    --multiprocessing-distributed       //是否使用多卡训练
    --batch-size                        //训练批次大小
    --amp                               //是否使用混合精度
    --epoch                             //重复训练次数
    --seed                              //使用随机数种子，默认：49
    --rank                              //进程编号，默认：0
    --loss-scale                        //混合精度lossscale大小
    --opt-level                         //混合精度类型
    --device                            //使用设备为GPU或者是NPU
    --print-freq                        //打印频率
    --data                              //数据集路径
    ```

# 训练结果展示
**表 2**  训练结果展示表

|  DEVICE  | PT版本 | Acc@1 |  FPS   | Epochs | AMP_Type |
| :------: | :----: | :---: | :----: | :----: | :------: |
| 1p-竞品 |  -   | - |  -   |  -   |    -    |
| 8p-竞品 |  -   | - |  -   |  -   |    -    |
|  1p-NPU  |  1.5   |  NA   |   698   |  1   |    O2    |
|  1p-NPU  |  1.8   | 77.8  | 991.29  |  104   |    O2    |
|  8p-NPU  |  1.5   | 77.36 |  3687   |  140   |    O2    |
|  8p-NPU  |  1.8   | 76.941 | 6734.24 |  104   |    O2    |


# 版本说明

## 变更

2020.09.14：首次发布

2022.09.01：更新内容，重新发布。

## 已知问题

无。