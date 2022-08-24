# FROM nvidia/cuda:10.2-cudnn8-devel-ubuntu18.04
# FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu18.04
FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

# env
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    NCCL_DEBUG=WARN \
    NCCL_SOCKET_IFNAME=^docker0,lo \
    PYTHON=python3 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8
# do not add conda/lib (easy conflict)
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:/usr/lib:/usr/local/lib

# Install Common Dependencies
RUN apt-get -qq update && \
    apt-get -qq install -y --allow-downgrades \
        # utils
        aptitude apt-utils bc binutils-multiarch ca-certificates linux-tools-generic \
        locales locate moreutils pdsh pkg-config software-properties-common sudo systemd zsh && \
    # add-apt-repository
    add-apt-repository ppa:criu/ppa && \
    apt-get -qq update && \
    apt-get -qq install -y --allow-downgrades \
        # file & process
        bzip2 cifs-utils criu cpio dkms kmod mergerfs nfs-common rsync supervisor psmisc unzip \
        # edit & view
        jq htop libncurses5-dev libncursesw5-dev lsof pciutils pv screen tmux valgrind vim \
        # build
        autoconf automake build-essential cmake dh-make libffi-dev libnl-3-dev libnl-route-3-dev libprotobuf-c1 make gcc ninja-build zlib1g-dev \
        # network
        curl ethtool git iputils-ping nginx wget \
        # ssh
        autossh openssh-client openssh-server ssh \
        # media
        ffmpeg libsndfile1 sox \
        # nvidia
        ibutils ibverbs-providers ibverbs-utils infiniband-diags iproute2 libibverbs1 libibverbs-dev librdmacm1 librdmacm-dev libnuma-dev perftest rdmacm-utils \
        # adding below packages to mitigate the vulnerabilities
        e2fsprogs fuse fuse2fs libcurl3-nss libdpkg-perl libpcre3 && \
    # clean
    apt-get clean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Open-MPI-UCX installation
ARG UCX_VERSION=1.13.0
RUN mkdir /tmp/ucx && cd /tmp/ucx && \
    wget -q https://github.com/openucx/ucx/releases/download/v${UCX_VERSION}/ucx-${UCX_VERSION}.tar.gz && \
    tar zxf ucx-${UCX_VERSION}.tar.gz && \
	cd ucx-${UCX_VERSION} && \
    ./configure --prefix=/usr/local --enable-optimizations --disable-assertions --disable-params-check --enable-mt && \
    make -s -j $(nproc --all) && \
    make install -s -j $(nproc) && \
    rm -rf /tmp/ucx

# Open-MPI installation
ARG OPENMPI_VERSION=4.1.4
RUN mkdir /tmp/openmpi && cd /tmp/openmpi && \
    wget -q https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-${OPENMPI_VERSION}.tar.gz && \
    tar zxf openmpi-${OPENMPI_VERSION}.tar.gz && \
    cd openmpi-${OPENMPI_VERSION} && \
    ./configure --with-ucx=/usr/local/ --enable-mca-no-build=btl-uct --enable-orterun-prefix-by-default --prefix=/usr/local/ --with-cuda && \
    make -s -j $(nproc) all && \
    make install -s -j $(nproc) && \
    ldconfig && \
    rm -rf /tmp/openmpi

# rdma-core for Mlnx_ofed as user space driver
ARG RDMA_VERSION=41.0
RUN mkdir /tmp/rdma-core && cd /tmp/rdma-core && \
    wget -q https://github.com/linux-rdma/rdma-core/releases/download/v${RDMA_VERSION}/rdma-core-${RDMA_VERSION}.tar.gz && \
    tar zxf rdma-core-${RDMA_VERSION}.tar.gz && \
    cd /tmp/rdma-core/rdma-core-${RDMA_VERSION} && \
    ./build.sh && \
    rm -rf /tmp/rdma-core

# Nvidia MOFED Driver
ARG MOFED_VERSION=5.7-1.0.2.0
RUN UBUNTU_VERSION=`lsb_release -r | awk '{print $2;}'` && cd /tmp && \
    wget -q http://content.mellanox.com/ofed/MLNX_OFED-${MOFED_VERSION}/MLNX_OFED_LINUX-${MOFED_VERSION}-ubuntu${UBUNTU_VERSION}-x86_64.tgz && \
    tar zxf MLNX_OFED_LINUX-${MOFED_VERSION}-ubuntu${UBUNTU_VERSION}-x86_64.tgz && \
    MLNX_OFED_LINUX-${MOFED_VERSION}-ubuntu${UBUNTU_VERSION}-x86_64/mlnxofedinstall --user-space-only --without-fw-update -q --force && \
    rm -rf /tmp/MLNX_OFED_LINUX* && \
    rm -rf /tmp/*.tgz

# Install latest version of nccl-rdma-sharp-plugins
ARG SHARP_VERSION=2.1.0 \
    SHARP_DIR=/usr/local/nccl-rdma-sharp-plugins
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${SHARP_DIR}/lib
RUN cd /tmp && \
    mkdir -p ${SHARP_DIR} && \
    git clone -b v${SHARP_VERSION} https://github.com/Mellanox/nccl-rdma-sharp-plugins.git && \
    cd nccl-rdma-sharp-plugins && \
    ./autogen.sh && \
    ./configure --prefix=${SHARP_DIR} --with-cuda=/usr/local/cuda --without-ucx && \
    make -s -j$(nproc) && \
    make install -s -j$(nproc) && \
    rm -rf /tmp/nccl-rdma-sharp-plugins

# nvtop (do not use apt install nvtop)
RUN cd /tmp && \
    git clone https://github.com/Syllo/nvtop.git && \
    mkdir -p nvtop/build && \
    cd nvtop/build && \
    cmake .. -DNVIDIA_SUPPORT=ON -DAMDGPU_SUPPORT=ON && \
    make -s -j$(nproc) && \
    make install -s -j $(nproc) && \
    rm -rf /tmp/nvtop

# Python & Conda
ARG PYTHON_VERSION=3.9 \
    CONDA_VERSION=39_4.12.0 \
    CONDA_DIR=/usr/local/conda
ENV PATH=$PATH:${CONDA_DIR}/bin
RUN wget -qO /tmp/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-py${CONDA_VERSION}-Linux-x86_64.sh && \
    bash /tmp/miniconda.sh -b -p ${CONDA_DIR} && \
    rm -rf /tmp/miniconda.sh && \
    conda install --update-all -y conda-package-handling python=${PYTHON_VERSION} pip requests setuptools wheel typing-extensions ffmpeg && \
    # clean
    conda clean -ay && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

############################## CONFIG ##############################
# Configure SSH, OMPI, NCCL, Conda
RUN echo "export PATH=${PATH}" >> /etc/profile && \
    echo "export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> /etc/profile && \
    mkdir -p /var/run/sshd && \
    # Allow OpenSSH to communicate across containers and nodes (faster connection but less safety)
    echo "PermitRootLogin yes" >>/etc/ssh/sshd_config && \
    echo "PermitRootLogin prohibit-password" >>/etc/ssh/sshd_config && \
    echo "PermitEmptyPasswords yes" >>/etc/ssh/sshd_config && \
    echo "StrictModes no" >>/etc/ssh/sshd_config && \
    echo "Port 22" >>/etc/ssh/sshd_config && \
    echo "UseDNS no" >>/etc/ssh/sshd_config && \
    # Fixes issues with connecting to ftp (https://github.com/atmoz/sftp/issues/11)
    sed -i "s+/usr/lib/openssh/sftp-server+internal-sftp+g" /etc/ssh/sshd_config && \
    # SSH login fix. In case user kicked off after login
    sed "s@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g" -i /etc/pam.d/sshd && \
    # Fix sudo setrlimit error in container (https://github.com/sudo-project/sudo/issues/42)
    echo "Set disable_coredump false" >> /etc/sudo.conf && \
    # Configure Open MPI and configure NCCL parameters
    mv /usr/local/bin/mpirun /usr/local/bin/mpirun.real && \
    echo "#!/bin/bash" > /usr/local/bin/mpirun && \
    echo "/usr/local/bin/mpirun.real --allow-run-as-root \"\$@\"" >> /usr/local/bin/mpirun && \
    chmod a+x /usr/local/bin/mpirun && \
    echo "hwloc_base_binding_policy = none" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "rmaps_base_mapping_policy = slot" >> /usr/local/etc/openmpi-mca-params.conf && \
    echo "NCCL_DEBUG=WARN" >> /etc/nccl.conf && \
    echo "NCCL_SOCKET_IFNAME=^docker0,lo" >> /etc/nccl.conf && \
    # Configure conda: (1) symlink of pip, python, etc.; (2) pip config;
    #   (3) defaultly create private envs in ~/.conda and share common pkgs in /use/local/conda
    groupadd condaGroup && \
    chgrp -R condaGroup ${CONDA_DIR} && \
    chmod 777 -R ${CONDA_DIR} && \
    # ln -s ${CONDA_DIR}/bin/* /usr/local/bin/ && \
    ln -s ${CONDA_DIR}/bin/conda /usr/local/bin/conda && \
    ln -s ${CONDA_DIR}/bin/python /usr/local/bin/python && \
    if [ -f /usr/local/bin/pip ]; then rm /usr/local/bin/pip; fi && \
    ln -s ${CONDA_DIR}/bin/pip /usr/local/bin/pip && \
    printf "[global]\nno-cache-dir = true\ndisable-pip-version-check = true\nroot-user-action = ignore\n" > /etc/pip.conf && \
    printf "always_yes: true\nauto_activate_base: false\nauto_update_conda: false\npip_interop_enabled: true\nssl_verify: false\nchannel_priority: flexible\nchannels:\n  - defaults\n  - conda-forge\nenvs_dirs:\n  - ~/.conda/envs\n  - ${CONDA_DIR}/envs\n" > ${CONDA_DIR}/.condarc && \
    printf "__conda_setup=\"\$(\'${CONDA_DIR}/bin/conda\' \'shell.bash\' \'hook\' 2> /dev/null)\"\nif [ $? -eq 0 ]; then\n    eval \"\$__conda_setup\"\nelse\n    if [ -f \"${CONDA_DIR}/etc/profile.d/conda.sh\" ]; then\n        . \"${CONDA_DIR}/etc/profile.d/conda.sh\"\n    else\n         export PATH=\"${CONDA_DIR}/bin:\$PATH\"\n    fi\nfi\nunset __conda_setup\n" >> /etc/profile

# nccl-tests
# RUN cd /tmp && \
#     git clone https://github.com/NVIDIA/nccl-tests.git && \
#     cd nccl-tests && \
#     make -s -j$(nproc) && \
#     # nccl
#     ./build/all_reduce_perf -g $(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l) && \
#     # open-mpi
#     mpirun --allow-run-as-root -np 2 ./build/all_reduce_perf -g $(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l) && \
#     rm -rf /tmp/nccl-tests

ADD entrypoint.sh /
RUN chmod a+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
