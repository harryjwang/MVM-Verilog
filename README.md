# MVM-Verilog
This project implements a matrix-vector multiplication (MVM) engine in Verilog HDL. The design is broken into modular RTL blocks: a dot8 unit for dot-product slices, an accum module for summation, and a ctrl module for sequencing. The mvm top module integrates these to compute products efficiently with pipelining and parallelism.

RTL simulation was key to the development process. Testbenches applied known matrix/vector pairs, while waveform traces were inspected to confirm signal alignment, pipeline progression, and accumulator updates. Debugging waveforms exposed issues such as misordered partial sums or control missteps, which were iteratively fixed until timing and functionality were verified.

This project reflects the workflow of hardware accelerator design: modular RTL coding, simulation-based verification, and waveform debugging. It provides practical experience in building compute blocks like those found in FPGA-based machine learning or DSP systems.
