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

import sys
import re

if __name__ == '__main__':
    if sys.argv[1].endswith('.log'):
        result_log = sys.argv[1]
        with open(result_log, 'r') as f:
            content = f.read()
        line = content.split("\n")
        for i in range(len(line)):
            if line[i].startswith("OVERALL"):
                overall = line[i]
        
        print("310 bs{} MOTA:{}".format(result_log.split('_')[1], overall.split()[14]))
        

    elif sys.argv[1].endswith('.txt'):
        result_txt = sys.argv[1]
        with open(result_txt, 'r') as f:
            content = f.read()
        txt_data_list = [i.strip() for i in re.findall(r':(.*?),', content.replace('\n', ',') + ',')]
        fps = float(txt_data_list[7].replace('samples/s', '')) * 4
        print('310 bs{} fps:{}'.format(result_txt.split('_')[3], fps))
