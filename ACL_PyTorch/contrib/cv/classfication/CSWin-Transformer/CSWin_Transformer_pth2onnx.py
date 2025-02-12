# Copyright (C) Huawei Technologies Co., Ltd 2022-2022. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import models
import onnx
import sys
import torch
import torchvision

from onnxsim import simplify
from timm import create_model
from timm.models import load_checkpoint

def pth2onnx(input_file, output_file, batch_size):
    model = create_model('CSWin_64_24322_small_224',
                          pretrained=False,
                          num_classes=1000,
                          drop_rate=0.0,
                          drop_connect_rate=None,  # DEPRECATED, use drop_path
                          drop_path_rate=0.1,
                          drop_block_rate=None,
                          global_pool=None,
                          bn_momentum=None,
                          bn_eps=None,
                          img_size=224,
                          use_chk=False)
    load_checkpoint(model, input_file, use_ema=True, strict=True)
    model.eval()
    dummy_input = torch.randn(int(batch_size), 3, 224, 224)
    torch.onnx.export(model, 
                      dummy_input, 
                      output_file, 
                      verbose=True, 
                      input_names=['input'], 
                      output_names=['output'],
                      opset_version=11
                      )
    model_sim, check = simplify(output_file, input_shapes={'input': [int(batch_size), 3, 224, 224]})
    onnx.save(model_sim, output_file)


if __name__ == '__main__':
    batch_size = sys.argv[1]
    input_file = sys.argv[2]
    output_file = sys.argv[3]
    pth2onnx(input_file, output_file, batch_size)
