atc --framework=5 --model=./models/vqa-vilbert_bs1_sim_modify.onnx --output=vqa-vilbert_bs1 --input_format=ND --input-shape="box-features:1,43,1024;box_coordinates:1,43,4;box_mask:1,43;q_token_ids:1,32;q_mask:1,32;q_type_ids:1,32" --out_nodes="Gemm_2971:0;Sigmoid_2972:0" --log=error --soc_version=Ascend310

