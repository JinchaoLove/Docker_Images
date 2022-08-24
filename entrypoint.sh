#!/bin/bash
set +e # entrypoint begin: ignoreErrors if any command fails
export DEBIAN_FRONTEND=noninteractive

# Add user into conda group
adduser $USER condaGroup

# CUDA compat mode: https://docs.aws.amazon.com/sagemaker/latest/dg/inference-gpu-drivers.html
verlte() {
    [ "$1" = "$2" ] || [ "$2" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

if [ -f /usr/local/cuda/compat/libcuda.so.1 ]; then
    nvcc -V
    CUDA_COMPAT_MAX_DRIVER_VERSION=$(readlink /usr/local/cuda/compat/libcuda.so.1 | cut -d'.' -f 3-)
    echo "♫ CUDA compat package requires Nvidia driver ⩽${CUDA_COMPAT_MAX_DRIVER_VERSION}"
    NVIDIA_DRIVER_VERSION=$(sed -n 's/^NVRM.*Kernel Module *\([0-9.]*\).*$/\1/p' /proc/driver/nvidia/version 2>/dev/null || true)
    echo "♫ Current installed Nvidia driver version is ${NVIDIA_DRIVER_VERSION}"
    if [ $(verlte $CUDA_COMPAT_MAX_DRIVER_VERSION $NVIDIA_DRIVER_VERSION) ]; then
        echo "♫ Setup CUDA compatibility libs path to LD_LIBRARY_PATH"
        export LD_LIBRARY_PATH=/usr/local/cuda/compat:$LD_LIBRARY_PATH
        echo $LD_LIBRARY_PATH
    else
        echo "♫ Skip CUDA compat libs setup as newer Nvidia driver is installed"
    fi
else
    echo "♫ Skip CUDA compat libs setup as package not found"
fi

# Delete old nvidia/cuda symbolic link for ubuntu18.04:
# https://github.com/NVIDIA/libnvidia-container/issues/50: libnvidia/cuda xxx is empty, not checked.
UBUNTU_VERSION=$(lsb_release -r | awk '{print $2;}' | tr -d '.')
if [ $UBUNTU_VERSION = 1804 ]; then
    ldconfig 2>errlog
    if [ -s errlog ]; then
        cat errlog | awk '{print $3}' | xargs rm
    fi
    rm -f errlog
fi

# CUDA strictly match mode:
# NVIDIA_DRIVER_VERSION=$(sed -n 's/^NVRM.*Kernel Module *\([0-9.]*\).*$/\1/p' /proc/driver/nvidia/version 2>/dev/null || true)
# NVIDIA_BINARY="NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
# echo "♫ Strict match using nvidia-installer of version ${NVIDIA_DRIVER_VERSION}"
# wget -q https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVER_VERSION}/${NVIDIA_BINARY}
# chmod a+x ${NVIDIA_BINARY}
# ./${NVIDIA_BINARY} --silent --ui=none --no-questions --accept-license --no-kernel-module

exec "$@" # entrypoint end: pass through any other commands
