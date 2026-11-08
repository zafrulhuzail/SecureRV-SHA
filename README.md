# SecureRV-SHA

SecureRV-SHA is an educational RV32I firmware-hashing experiment. The baseline uses RV32I C code for SHA-256 compression. The accelerated firmware sends padded blocks to a memory-mapped compression engine. Both configurations use the same CPU RTL and simulation RAM.

## Reproduce locally

In Ubuntu 24.04, including on WSL2, install the open-source tools and run these commands from the project root:

```bash
sudo apt update
sudo apt install verilator build-essential gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf python3 yosys
bash scripts/test-alu.sh
bash scripts/run-suite.sh
bash scripts/synth.sh
```

On Windows, open Ubuntu in Windows Terminal. Windows drives appear under `/mnt`. Quote project paths with spaces, or copy the project into the Linux filesystem. From PowerShell, `wsl --install -d Ubuntu-24.04` installs the distribution if needed.

`run-suite.sh` includes the standalone ALU and accelerator tests, builds RV32I/ILP32 assembly and C with GCC, exercises CPU traps, and validates both configurations against Python's SHA-256 implementation. Set `CROSS_COMPILE` to override the toolchain prefix. Add `+trace` to the suite command to write `build/suite/soc.vcd` for the accelerated run. For an ALU trace, run `bash scripts/test-alu.sh +trace`.

The suite writes simulator logs and `build/suite/results.csv`. Throughput assumes 50 MHz by default. To recompute it, run the following from the root:

```bash
(cd build/suite && python3 ../../benchmarks/report.py --clock-hz 25000000)
```

## Source layout

| Directory | Contents |
| --- | --- |
| tl/secure_soc.sv | Synthesizable baseline and accelerated system wrapper |
| tl/core | Combinational ALU, instruction decoder, register file and multicycle CPU |
| `rtl/sha256` | Memory-mapped SHA-256 compression engine |
| `testbench` | Standalone unit tests and CPU system simulation harness |
| `software/baremetal` | Reset entry, link layout and assembly diagnostics |
| `software/sha256` | Shared byte packing and padding, C compression and MMIO driver |
| `benchmarks` | Firmware input cases, digest checks and report generator |
| `docs` | Architecture, MMIO protocol and measurement methodology |

See [architecture and methods](docs/architecture.md) for the supported execution environment and measurement boundaries.

See [measured results](docs/results.md) for the verified cycle and synthesis comparison.
