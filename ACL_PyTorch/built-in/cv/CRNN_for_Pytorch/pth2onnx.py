# Copyright 2021 Huawei Technologies Co., Ltd
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

import torch
import crnn
import onnx
import torch.onnx
import sys
from collections import OrderedDict

def proc_node_module(checkpoint, AttrName):
    new_state_dict = OrderedDict()
    for k, v in checkpoint[AttrName].items():
        if (k[0:7] == "module."):
            name = k[7:]
        else:
            name = k[0:]
        new_state_dict[name] = v
    return new_state_dict


def lstm_op_adapter(state_dict):
    ret = {}
    for key, value in state_dict.items():
        if not (key.startswith('rnn') and ('fw' in key or 'bw' in key)):
            ret[key] = value
            continue
        param = state_dict[key].data.split(256)
        ret[key] = torch.cat((param[0], param[2], param[1], param[3]), 0)
    return ret

def convert(path, out):
    checkpoint = torch.load(path, map_location='cpu')
    checkpoint['state_dict'] = proc_node_module(checkpoint, 'state_dict')
    model = crnn.CRNN(32, 1, 37, 256)
    model.load_state_dict(lstm_op_adapter(checkpoint['state_dict']))
    model.eval()
    print(model)

    input_names = ["actual_input_1"]
    output_names = ["output1"]
    dummy_input = torch.randn(1, 1, 32, 100)
    dynamic_axes = {'actual_input_1': {0: '-1'}, 'output1': {1: '-1'}}
    print('\nStarting ONNX export with onnx %s...' % onnx.__version__)
    torch.onnx.export(model, 
                    dummy_input, 
                    out, 
                    input_names=input_names, 
                    dynamic_axes = dynamic_axes, 
                    output_names=output_names, 
                    opset_version=11)


if __name__ == "__main__":
    path = sys.argv[1]
    out = sys.argv[2]
    convert(path, out)
