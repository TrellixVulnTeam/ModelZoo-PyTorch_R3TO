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


import re
import os
import argparse
from tqdm import tqdm

import torch
from torch.utils.data import DataLoader
import yaml
import numpy as np
from scipy.io import wavfile
import aclruntime

from utils.tools import to_device, get_mask_from_lengths, pad
from dataset import TextDataset


def expand(batch, predicted):
    out = list()

    for i, vec in enumerate(batch):
        expand_size = predicted[i].item()
        out.append(vec.expand(max(int(expand_size), 0), -1))
    out = torch.cat(out, 0)

    return out


def LR(x, duration, max_len=None):
    output = list()
    mel_len = list()
    for batch, expand_target in zip(x, duration):
        expanded = expand(batch, expand_target)
        output.append(expanded)
        mel_len.append(expanded.shape[0])

    if max_len is not None:
        output = pad(output, max_len)
    else:
        output = pad(output)

    return output, torch.LongTensor(mel_len)


def om_infer(om, input_data, mode):
    inputs = []
    shape = []
    for in_data in input_data:
        if torch.is_tensor(in_data):
            shape.append(in_data.numpy().shape)
            in_data = aclruntime.Tensor(in_data.numpy())
        elif type(in_data) is np.ndarray:
            shape.append(in_data.shape)
            in_data = aclruntime.Tensor(in_data)
        elif type(in_data) is np.float64:
            shape.append(in_data.size)
            in_data = aclruntime.Tensor(in_data)
        else:
            shape.append(np.array(in_data).shape)
        in_data.to_device(args.device_id)
        inputs.append(in_data)

    innames = [inp.name for inp in om.get_inputs()]
    outnames = [out.name for out in om.get_outputs()]

    for i, inp in enumerate(innames):
        if i == 0:
            dynamic_shape = re.sub('[()\s]', '', f"{inp}:{shape[i]}")
        else:
            dynamic_shape += re.sub('[()\s]', '', f";{inp}:{shape[i]}")

    if mode == 'dynamic':
        om.set_dynamic_shape(dynamic_shape)
        om.set_custom_outsize([1000000] * len(outnames))
    elif mode == 'multi':
        om.set_dynamic_dims(dynamic_shape)
    else:
        pass

    outputs = om.run(outnames, inputs)
    output_data = []
    for out in outputs:
        out.to_host()
        output_data.append(out)

    return output_data


def fastspeech2_infer(texts, src_masks, fastspeech2_om, control_values):
    encoder_om, variance_adaptor_om, decoder_om, postnet_om = fastspeech2_om
    pitch_control, energy_control, duration_control = np.array(control_values)

    # encoder infer
    enc_output = om_infer(encoder_om, [texts, src_masks], 'dynamic')

    # variance_adaptor infer
    output_tmp = om_infer(variance_adaptor_om, [enc_output[0], src_masks,
                                                pitch_control, energy_control, duration_control], 'dynamic')

    output = torch.from_numpy(np.array(output_tmp[0]))
    d_rounded = torch.from_numpy(np.array(output_tmp[1]))
    output, mel_lens = LR(output, d_rounded)
    mel_masks = get_mask_from_lengths(mel_lens)

    # decoder infer
    dec_output = om_infer(decoder_om, [output, mel_masks], 'dynamic')

    # postnet infer
    mel_output = om_infer(postnet_om, [dec_output[0]], 'dynamic')

    return (mel_output, mel_lens)


def get_shape(wav_shape):
    multi_shape = [250, 500, 750, 1000, 1250, 1500, 1750, 2000]
    for shape in multi_shape:
        if wav_shape < shape:
            return shape
    return max(multi_shape)


def hifigan_infer(ids, mel_output, mel_lens, preprocess_config, train_config, hifigan_om):
    model_shape = get_shape(mel_output[0].shape[1])
    x_pad = np.pad(mel_output[0], ((0, 0), (0, model_shape - mel_output[0].shape[1]), (0, 0)),
                   mode="constant", constant_values=0)

    wavs = om_infer(hifigan_om, [x_pad], 'multi')

    max_wav_value = preprocess_config["preprocessing"]["audio"]["max_wav_value"]
    lengths = mel_lens * preprocess_config["preprocessing"]["stft"]["hop_length"]
    sampling_rate = preprocess_config["preprocessing"]["audio"]["sampling_rate"]

    wavs = (np.array(wavs[0]) * max_wav_value).astype("int16")
    wavs = [wav for wav in wavs]

    for i in range(len(mel_lens)):
        wavs[i] = wavs[i][: lengths[i]]

    for wav, id in zip(wavs, ids):
        wavfile.write(os.path.join(train_config["path"]["result_path"], f"{id}.wav"), sampling_rate, wav)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=str, default=None,
                        help="path to a source file with format like train.txt and val.txt")
    parser.add_argument("--om_path", type=str, default="output/om", help="path to load FastSpeech2 om model")
    parser.add_argument("--encoder", type=str, default="encoder_bs{}.om", help="path to om")
    parser.add_argument("--variance_adaptor", type=str, default="variance_adaptor_bs{}.om", help="path to om")
    parser.add_argument("--decoder", type=str, default="decoder_bs{}.om", help="path to om")
    parser.add_argument("--postnet", type=str, default="postnet_bs{}.om", help="path to om")
    parser.add_argument("--vocoder", type=str, default="hifigan_bs{}.om", help="path to om")
    parser.add_argument("-p", "--preprocess_config", type=str, help="path to preprocess.yaml")
    parser.add_argument("-t", "--train_config", type=str, help="path to train.yaml")
    parser.add_argument("-vp", "--pitch_control", type=float, default=1.0,
                        help="control the pitch of the whole utterance, larger value for higher pitch")
    parser.add_argument("-ve", "--energy_control", type=float, default=1.0,
                        help="control the energy of the whole utterance, larger value for larger volume")
    parser.add_argument("-vd", "--duration_control", type=float, default=1.0,
                        help="control the speed of the whole utterance, larger value for slower speaking rate")
    parser.add_argument("--batch-size", type=int, default=1, help="batch size")
    parser.add_argument("--device_id", type=int, default=0, help="device id")
    args = parser.parse_args()

    # read config
    preprocess_config = yaml.load(open(args.preprocess_config, "r"), Loader=yaml.FullLoader)
    train_config = yaml.load(open(args.train_config, "r"), Loader=yaml.FullLoader)

    # load dataset
    dataset = TextDataset(args.source, preprocess_config)
    batchs = DataLoader(dataset, batch_size=args.batch_size, collate_fn=dataset.collate_fn)
    print("load dataset success")

    # load model
    options = aclruntime.session_options()
    encoder_om = aclruntime.InferenceSession(os.path.join(args.om_path, args.encoder.format(args.batch_size)),
                                             args.device_id, options)
    variance_adaptor_om = aclruntime.InferenceSession(
        os.path.join(args.om_path, args.variance_adaptor.format(args.batch_size)),
        args.device_id, options)
    decoder_om = aclruntime.InferenceSession(os.path.join(args.om_path, args.decoder.format(args.batch_size)),
                                             args.device_id, options)
    postnet_om = aclruntime.InferenceSession(os.path.join(args.om_path, args.postnet.format(args.batch_size)),
                                             args.device_id, options)
    fastspeech2_om = (encoder_om, variance_adaptor_om, decoder_om, postnet_om)
    hifigan_om = aclruntime.InferenceSession(os.path.join(args.om_path, args.vocoder.format(args.batch_size)),
                                             args.device_id, options)
    print("load model success")

    control_values = args.pitch_control, args.energy_control, args.duration_control

    for batch in tqdm(batchs):
        batch = to_device(batch, 'cpu')
        src_masks = get_mask_from_lengths(batch[4], batch[5])
        mel_output, mel_lens = fastspeech2_infer(batch[3], src_masks, fastspeech2_om, control_values)
        hifigan_infer(batch[0], mel_output, mel_lens, preprocess_config, train_config, hifigan_om)
