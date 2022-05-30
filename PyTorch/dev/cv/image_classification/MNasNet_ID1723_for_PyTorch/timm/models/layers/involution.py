#
# BSD 3-Clause License
#
# Copyright (c) 2017 xxxx
# All rights reserved.
# Copyright 2021 Huawei Technologies Co., Ltd
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ============================================================================
#
""" PyTorch Involution Layer

Official impl: https://github.com/d-li14/involution/blob/main/cls/mmcls/models/utils/involution_naive.py
Paper: `Involution: Inverting the Inherence of Convolution for Visual Recognition` - https://arxiv.org/abs/2103.06255
"""
import torch.nn as nn
from .conv_bn_act import ConvBnAct
from .create_conv2d import create_conv2d
import torch.npu
import os
NPU_CALCULATE_DEVICE = 0
if os.getenv('NPU_CALCULATE_DEVICE') and str.isdigit(os.getenv('NPU_CALCULATE_DEVICE')):
    NPU_CALCULATE_DEVICE = int(os.getenv('NPU_CALCULATE_DEVICE'))
if torch.npu.current_device() != NPU_CALCULATE_DEVICE:
    torch.npu.set_device(f'npu:{NPU_CALCULATE_DEVICE}')


class Involution(nn.Module):

    def __init__(
            self,
            channels,
            kernel_size=3,
            stride=1,
            group_size=16,
            rd_ratio=4,
            norm_layer=nn.BatchNorm2d,
            act_layer=nn.ReLU,
    ):
        super(Involution, self).__init__()
        self.kernel_size = kernel_size
        self.stride = stride
        self.channels = channels
        self.group_size = group_size
        self.groups = self.channels // self.group_size
        self.conv1 = ConvBnAct(
            in_channels=channels,
            out_channels=channels // rd_ratio,
            kernel_size=1,
            norm_layer=norm_layer,
            act_layer=act_layer)
        self.conv2 = self.conv = create_conv2d(
            in_channels=channels // rd_ratio,
            out_channels=kernel_size**2 * self.groups,
            kernel_size=1,
            stride=1)
        self.avgpool = nn.AvgPool2d(stride, stride) if stride == 2 else nn.Identity()
        self.unfold = nn.Unfold(kernel_size, 1, (kernel_size-1)//2, stride)

    def forward(self, x):
        weight = self.conv2(self.conv1(self.avgpool(x)))
        B, C, H, W = weight.shape
        KK = int(self.kernel_size ** 2)
        weight = weight.view(B, self.groups, KK, H, W).unsqueeze(2)
        out = self.unfold(x).view(B, self.groups, self.group_size, KK, H, W)
        out = (weight * out).sum(dim=3).view(B, self.channels, H, W)
        return out
