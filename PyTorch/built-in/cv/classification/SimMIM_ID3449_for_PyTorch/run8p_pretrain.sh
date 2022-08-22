source env_npu.sh
export WORLD_SIZE=8
rm -f nohup.out

for((RANK_ID=0;RANK_ID<WORLD_SIZE;RANK_ID++));
do
    export RANK=$RANK_ID

    nohup python3 main_simmim.py  \
        --cfg configs/swin_base__100ep/simmim_pretrain__swin_base__img192_window6__100ep.yaml \
        --batch-size 128 \
        --amp-opt-level O1 \
        --local_rank $RANK_ID \
        --data-path /data/imagenet/train &
done
