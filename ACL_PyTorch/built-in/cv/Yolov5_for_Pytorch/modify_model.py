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
import onnx
import argparse
from onnx import helper


def ceil_x(value, align_len):
    return (value + align_len - 1) // align_len * align_len


def main(args):
    model_path = args.model
    model = onnx.load(model_path)

    bs = args.batch_size
    yolo_coord, yolo_obj, yolo_classes = [], [], []
    yolo_node = []
    yolo_num = 3
    cls_num = args.class_num
    boxes = 3
    coords = 4

    args.img_size *= 2 if len(args.img_size) == 1 else 1  # expand
    h, w = args.img_size
    # create yolo layer
    f_h, f_w = h // 8, w // 8
    for i in range(yolo_num):
        crd_align_len = ceil_x(f_h * f_w * 2 + 32, 32) // 2
        obj_align_len = ceil_x(boxes * f_h * f_w * 2 + 32, 32) // 2

        yolo_coord.append(helper.make_tensor_value_info(f"yolo{i}_coord", onnx.TensorProto.FLOAT, [bs, boxes * coords, crd_align_len]))
        yolo_obj.append(helper.make_tensor_value_info(f"yolo{i}_obj", onnx.TensorProto.FLOAT, [bs, obj_align_len]))
        yolo_classes.append(helper.make_tensor_value_info(f"yolo{i}_classes", onnx.TensorProto.FLOAT, [bs, cls_num, obj_align_len]))

        yolo_node.append(helper.make_node('YoloPreDetection',
                                          inputs=[model.graph.output[i].name],
                                          outputs=[f"yolo{i}_coord", f"yolo{i}_obj", f"yolo{i}_classes"],
                                          boxes=boxes,
                                          coords=coords,
                                          classes=cls_num,
                                          yolo_version='V5',
                                          name=f'yolo_{i}'))
        model.graph.node.append(yolo_node[i])
        f_h, f_w = f_h // 2, f_w // 2

    # create yolo detection output layer
    img_info = helper.make_tensor_value_info("img_info", onnx.TensorProto.FLOAT, [bs, 4])
    box_out = helper.make_tensor_value_info("box_out", onnx.TensorProto.FLOAT, [bs, 6 * 1024])
    box_out_num = helper.make_tensor_value_info("box_out_num", onnx.TensorProto.INT32, [bs, 8])
    yolo_detout_node = helper.make_node('YoloV5DetectionOutput',
                                        inputs=[f"yolo{i}_coord" for i in range(3)] +
                                               [f"yolo{i}_obj" for i in range(3)] +
                                               [f"yolo{i}_classes" for i in range(3)] +
                                               ['img_info'],
                                        outputs=['box_out', 'box_out_num'],
                                        boxes=boxes,
                                        coords=coords,
                                        classes=cls_num,
                                        pre_nms_topn=1024,
                                        post_nms_topn=1024,
                                        relative=1,
                                        out_box_dim=2,
                                        obj_threshold=args.conf_thres,
                                        score_threshold=args.conf_thres,
                                        iou_threshold=args.iou_thres,
                                        biases=args.anchors,
                                        name='YoloV5DetectionOutput_1')

    # add input and output
    model.graph.node.append(yolo_detout_node)
    while len(model.graph.output) > 0:
        model.graph.output.remove(model.graph.output[0])

    model.graph.input.append(img_info)
    model.graph.output.append(box_out)
    model.graph.output.append(box_out_num)

    onnx.save(model, model_path.split('.onnx')[0] + "_t.onnx")
    print("success")


if __name__ == '__main__':
    parser = argparse.ArgumentParser("modify yolov5 onnx model for atc convert")
    parser.add_argument('--model', type=str, default='./yolov5s_sim.onnx', help='model path')
    parser.add_argument('--img-size', nargs='+', type=int, default=[640, 640], help='image size')  # height, width
    parser.add_argument('--batch-size', type=int, default=1, help='batch size')
    parser.add_argument('--conf-thres', type=float, default=0.4, help='object confidence threshold')
    parser.add_argument('--iou-thres', type=float, default=0.5, help='IOU threshold for NMS')
    parser.add_argument('--class-num', type=int, default=80, help='class num')
    parser.add_argument('--anchors', type=float, nargs='+', default=[10., 13, 16, 30, 33, 23, 30, 61, 62, 45, 59, 119, 116, 90, 156, 198, 373, 326], help='anchors')
    flags = parser.parse_args()
    main(flags)
