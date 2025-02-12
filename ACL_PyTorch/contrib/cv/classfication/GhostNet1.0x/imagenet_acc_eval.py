# Copyright 2022 Huawei Technologies Co., Ltd
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

import argparse
import sys
import os
import json
import numpy as np

def read_info_from_json(json_path):
    '''
    此函数用于读取inference_tools生成的json文件
    输入：json文件地址
    输出：dict结构；为原始的json转换出来的结构
    '''
    if os.path.exists(json_path) is False:
        print(json_path, 'is not exist')
    with open(json_path, 'r') as f:
        load_data = json.load(f)
        file_info = load_data['filesinfo']
        return file_info

def read_label_from_txt(txt_path):
    label_info = {}
    if os.path.exists(txt_path) is False:
        print(txt_path, 'is not exist')
    with open(txt_path, 'r') as f:
        labels = f.readlines()
        for label in labels:
            label = label.strip()
            label_info[label.split(' ')[0]] = int(label.split(' ')[1])
        return label_info

def postProcesss(result_path, txt_path):
    file_info = read_info_from_json(result_path)
    labels_info = read_label_from_txt(txt_path)

    outputs = []
    labels = []
    for i in file_info.items():
        # 获取推理结果文件地址
        res_path = i[1]['outfiles'][0]

        # 获取GT
        img_path = i[1]['infiles'][0].split('/')[-1].replace('bin', 'JPEG')
        label = labels_info[img_path]
        # 获取pred_logits
        ndata = np.load(res_path)
        res_out = np.mean(ndata, axis=0)

        outputs.append(res_out)
        labels.append(label)
        print("=>process {}".format(img_path))
    return outputs, labels

def mean_class_accuracy(scores, labels):

    pred = np.argmax(scores, axis=1)
    cf_mat = confusion_matrix(pred, labels).astype(float)

    cls_cnt = cf_mat.sum(axis=1)
    cls_hit = np.diag(cf_mat)

    mean_class_acc = np.mean(
        [hit / cnt if cnt else 0.0 for cnt, hit in zip(cls_cnt, cls_hit)])

    return mean_class_acc


def top_k_accuracy(scores, labels, topk=(1, )):
    res = []
    labels = np.array(labels)[:, np.newaxis]
    for k in topk:
        max_k_preds = np.argsort(scores, axis=1)[:, -k:][:, ::-1]
        match_array = np.logical_or.reduce(max_k_preds == labels, axis=1)
        topk_acc_score = match_array.sum() / match_array.shape[0]
        res.append(topk_acc_score)

    return res

def confusion_matrix(y_pred, y_real, normalize=None):

    if normalize not in ['true', 'pred', 'all', None]:
        raise ValueError("normalize must be one of {'true', 'pred', "
                         "'all', None}")

    if isinstance(y_pred, list):
        y_pred = np.array(y_pred)
    if not isinstance(y_pred, np.ndarray):
        raise TypeError(
            f'y_pred must be list or np.ndarray, but got {type(y_pred)}')
    if not y_pred.dtype == np.int64:
        raise TypeError(
            f'y_pred dtype must be np.int64, but got {y_pred.dtype}')

    if isinstance(y_real, list):
        y_real = np.array(y_real)
    if not isinstance(y_real, np.ndarray):
        raise TypeError(
            f'y_real must be list or np.ndarray, but got {type(y_real)}')
    if not y_real.dtype == np.int64:
        raise TypeError(
            f'y_real dtype must be np.int64, but got {y_real.dtype}')

    label_set = np.unique(np.concatenate((y_pred, y_real)))
    num_labels = len(label_set)
    max_label = label_set[-1]
    label_map = np.zeros(max_label + 1, dtype=np.int64)
    for i, label in enumerate(label_set):
        label_map[label] = i

    y_pred_mapped = label_map[y_pred]
    y_real_mapped = label_map[y_real]

    confusion_mat = np.bincount(
        num_labels * y_real_mapped + y_pred_mapped,
        minlength=num_labels**2).reshape(num_labels, num_labels)

    with np.errstate(all='ignore'):
        if normalize == 'true':
            confusion_mat = (
                confusion_mat / confusion_mat.sum(axis=1, keepdims=True))
        elif normalize == 'pred':
            confusion_mat = (
                confusion_mat / confusion_mat.sum(axis=0, keepdims=True))
        elif normalize == 'all':
            confusion_mat = (confusion_mat / confusion_mat.sum())
        confusion_mat = np.nan_to_num(confusion_mat)

    return confusion_mat


if __name__ == '__main__':
    try:
        # json file path
        pred = sys.argv[1]
        # annotation files path, "val_label.txt"
        gt = sys.argv[2]
        # # the path to store the results json path
        # result_json_path = sys.argv[3]
        # # result json file name
        # json_file_name = sys.argv[4]
    except IndexError:
        print("Stopped!")
        exit(1)
    outputs, labels = postProcesss(pred, gt)
    print('Evaluating top_k_accuracy ...')
    top_acc = top_k_accuracy(outputs, labels, topk=(1, 5))
    print(f'\ntop{1}_acc\t{top_acc[0]:.4f}')
    print(f'\ntop{5}_acc\t{top_acc[1]:.4f}')

    print('Evaluating mean_class_accuracy ...')
    mean_acc = mean_class_accuracy(outputs, labels)
    print(f'\nmean_acc\t{mean_acc:.4f}')
