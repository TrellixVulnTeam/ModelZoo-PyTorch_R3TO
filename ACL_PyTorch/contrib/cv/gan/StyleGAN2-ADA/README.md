# Stylegan2-ADA-Pytorch模型PyTorch离线推理指导

## 1 环境准备 

1.安装必要的依赖，测试环境可能已经安装其中的一些不同版本的库了，故手动测试时不推荐使用该命令安装  

```
pip install -r requirements.txt  
```


2.获取，修改与安装开源模型代码  

```
(torch 1.7.0以上版本)git clone https://github.com/NVlabs/stylegan2-ada-pytorch.git model
(torch 1.5.0)git clone https://github.com/Hypersus/utils-for-stylegan2-ada-pytorch.git model
```


3.获取权重文件  

将权重文件G_ema_bs8_8p_kimg1000.pkl放到当前工作目录  

4.数据集     
执行`python stylegan2-ada-pytorch_preprocess.py`，默认生成`batch_size=1`的一条输入，保存在`./input`目录下



5.获取ais-infer工具

参考[ais-infer工具源码地址](https://gitee.com/ascend/tools/tree/master/ais-bench_workload/tool/ais_infer)安装将工具编译后的压缩包放置在当前目录；解压工具包，安装工具压缩包中的whl文件；

```
pip3 install aclruntime-0.01-cp37-cp37m-linux_xxx.whl
```

将ais-infer工具完整目录放到当前工作目录



## 2 离线推理 

310上执行，执行时使npu-smi info查看设备状态，确保device空闲  

```
bash test/pth2om.sh  
bash test/eval_acc_perf.sh
```
 **评测结果：**   

bs1在310上推理的性能

```
Inference average time : 207.61 ms
Inference average time without first time: 207.59 ms
```

bs1 310单卡吞吐率：1000/(207.61/4)=19.27fps

bs1在T4上推理的性能

```
Inference average time : 317.90 ms
```



|           模型            |  T4性能  | 310性能  |
| :-----------------------: | :------: | :------: |
| stylegan2-ada-pytorch bs1 | 12.58fps | 19.27fps |

