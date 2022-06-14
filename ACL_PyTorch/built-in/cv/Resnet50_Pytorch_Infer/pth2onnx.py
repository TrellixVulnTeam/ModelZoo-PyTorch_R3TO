import sys

import torch
import torch.onnx
import torchvision.models as models


def convert(pthfile):
    model = models.resnet50(pretrained=False)
    resnet50 = torch.load(pthfile, map_location='cpu')
    model.load_state_dict(resnet50)
    print(model)

    input_names = ["actual_input_1"]
    output_names = ["output1"]
    dummy_input = torch.randn(16, 3, 224, 224)
    torch.onnx.export(
        model, 
        dummy_input,
        "resnet50_official.onnx",
        input_names=input_names, 
        output_names=output_names, 
        opset_version=11)


if __name__ == "__main__":
    pth_path = sys.argv[1]
    convert(pth_path)

