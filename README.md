# Deep learning images

Deep learning images in [Docker Hub: jinchaolove/dl](https://hub.docker.com/repository/docker/jinchaolove/dl) developed from `nvidia/cuda-cudnn-devel-ubuntu`, with support of communications between containers and GPUs.

## Features

`UCX`, `Open MPI`, `ADMA`, `OFED`, `SHARP` are default installed to support distributed training with NVIDIA `NCCL`. All images are tested and passed the NVIDIA [NCCL Tests](https://github.com/NVIDIA/nccl-tests).

`conda3` is installed in a [multi-user](https://docs.anaconda.com/anaconda/install/multi-user) manner (run `adduser $USER condaGroup` for new users). **Private** `envs` are created in `~/.conda` and **common** `pkgs` are shared in `/use/local/conda` by default. The `python` (`python3.9`) and `pip` (`pip3`) are soft linked from `conda3` by default.

CUDA compatibility is enabled by adding `ENTRYPOINT` script in `/entrypoint.sh`. See [Best practices for working with mismatched driver versions](https://docs.aws.amazon.com/sagemaker/latest/dg/inference-gpu-drivers.html).

## Versions

- `ubuntu`: `18.04` (32 & 64-bit, python2 & 3), `20.04` (64-bit, python3)
- `cuda`: `10.2`, `11.3`, `11.6` (backward and minor version forward compatible)

## Usages

- Build the image (*recommend modify yours from the base image in [jinchaolove/dl](https://hub.docker.com/repository/docker/jinchaolove/dl) instead of re-built from start, see example in `Dockerfile.msra`*):

```sh
# docker build -t <name>:<tag> -f Dockerfile .  # base image
cat Dockerfile.msra | docker build - -t <name>:<tag>  # job-specified image
```

- Run the container:

```sh
docker run -ti <name>:<tag> /bin/bash
```

- Others: please see [docker docs](https://docs.docker.com)

## Authors

Please give me a 🌟 if this repository helps you 🤗

If you have any questions, please feel free to issue or contact me ([Jinchao](http://jinchaoli.com)).
