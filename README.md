ocaml-nvml [![Build status](https://travis-ci.org/johnelse/ocaml-nvml.png?branch=master)](https://travis-ci.org/johnelse/ocaml-nvml)
==========

OCaml bindings to the [NVIDIA Management Library](https://developer.nvidia.com/nvidia-management-library-nvml)

Commands mirror the NVML API - see the original
[API reference](http://developer.download.nvidia.com/assets/cuda/files/CUDADownloads/NVML/nvml.pdf)
for more information.

Build requirements:

* [ctypes](https://github.com/ocamllabs/ocaml-ctypes)

Also requires libnvidia-ml.so to be in your dynamic library path at runtime.
