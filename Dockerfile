# 使用Ubuntu 22.04作为基础镜像
FROM ubuntu:22.04 as base

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive

# 更新系统包并安装必要的工具和依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    python3 \
    python3-pip \
    python3.10-venv \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /workspace

# 创建虚拟环境
RUN python3 -m venv --system-site-packages /root/venv

RUN pip install expecttest types-dataclasses lark optree hypothesis psutil pyyaml requests sympy filelock networkx jinja2 fsspec packaging numpy

# 激活虚拟环境
ENV PATH="/root/venv/bin:$PATH"

# 安装其他依赖项
RUN pip install wheel

# 下载并解压PyTorch源码
RUN wget https://github.com/pytorch/pytorch/releases/download/v2.3.0/pytorch-v2.3.0.tar.gz \
    && tar xvf pytorch-v2.3.0.tar.gz

# 进入PyTorch源码目录
WORKDIR /workspace/pytorch-v2.3.0

# 更新cpuinfo
RUN cd third_party/ \
    && rm -rf cpuinfo/ \
    && git clone https://github.com/sophgo/cpuinfo.git

# 修改CMakeLists.txt文件
RUN sed -i 's/if(NOT MSVC AND NOT EMSCRIPTEN AND NOT INTERN_BUILD_MOBILE)/if(FALSE)/' aten/src/ATen/CMakeLists.txt \
    && sed -i 's/target_link_libraries(${test_name}_${CPU_CAPABILITY} c10 sleef gtest_main)/target_link_libraries(${test_name}_${CPU_CAPABILITY} c10 gtest_main)/' caffe2/CMakeLists.txt \
    && sed -i 's/add_executable(test_api ${TORCH_API_TEST_SOURCES})/add_executable(test_api ${TORCH_API_TEST_SOURCES})\ntarget_compile_options(test_api PUBLIC -Wno-nonnull)/' test/cpp/api/CMakeLists.txt

# 创建构建脚本
RUN echo '#!/bin/bash' > build.sh \
    && echo 'export USE_CUDA=0' >> build.sh \
    && echo 'export USE_DISTRIBUTED=0' >> build.sh \
    && echo 'export USE_MKLDNN=0' >> build.sh \
    && echo 'export MAX_JOBS=5' >> build.sh \
    && echo 'python3 setup.py bdist_wheel' >> build.sh

# 使构建脚本可执行
RUN chmod +x build.sh && cp build.sh /workspace/pytorch-v2.3.0/build.sh

# 设置工作目录为PyTorch源码目录
WORKDIR /workspace/pytorch-v2.3.0

# 手动执行构建脚本
CMD ["bash", "build.sh"]
