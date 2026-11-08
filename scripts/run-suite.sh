#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
prefix=${CROSS_COMPILE:-riscv64-unknown-elf-}
for tool in verilator make g++ python3 "${prefix}gcc" "${prefix}objcopy"; do
    command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 127; }
done
bash scripts/test-alu.sh
mkdir -p build/suite
verilator --binary --assert --timescale 1ns/1ps -j 2 --Mdir build/suite/core-units \
    --top-module tb_core_units rtl/core/decoder.sv rtl/core/register_file.sv testbench/core/tb_core_units.sv
build/suite/core-units/Vtb_core_units
flags=(-march=rv32i -mabi=ilp32 -O2 -ffreestanding -fno-builtin
       -fno-tree-loop-distribute-patterns -fno-pic -msmall-data-limit=0
       -nostdlib -Wl,--no-relax -T software/baremetal/link.ld)
build_image() {
    local name=$1
    shift
    "${prefix}gcc" "${flags[@]}" software/baremetal/start.S "$@" -o "build/suite/$name.elf"
    "${prefix}objcopy" -O binary "build/suite/$name.elf" "build/suite/$name.bin"
    python3 -c 'import sys; print("\n".join(f"{b:02x}" for b in open(sys.argv[1], "rb").read()))' \
        "build/suite/$name.bin" > "build/suite/$name.hex"
}
build_image smoke software/baremetal/smoke.S
sources=(-I software/sha256 benchmarks/firmware.c software/sha256/sha256.c)
build_image baseline "${sources[@]}"
build_image accelerated -DUSE_ACCEL "${sources[@]}"
printf 'ff\nff\nff\nff\n' > build/suite/illegal.hex
printf '83\n20\n10\n00\n' > build/suite/misaligned.hex
printf '6f\n00\n20\n00\n' > build/suite/misaligned-jump.hex
printf 'b7\n00\n02\n00\n03\na1\n00\n00\n' > build/suite/access-fault.hex
verilator --binary --assert --timescale 1ns/1ps -j 2 \
    --Mdir build/suite/unit --top-module tb_sha256 \
    rtl/sha256/sha256_mmio.sv testbench/sha256/tb_sha256.sv
build/suite/unit/Vtb_sha256

for accel in 0 1; do
    verilator --binary --assert --trace --timescale 1ns/1ps -j 2 \
        --Mdir "build/suite/soc$accel" --top-module tb_soc "-GACCEL=$accel" \
        rtl/core/*.sv rtl/sha256/sha256_mmio.sv rtl/secure_soc.sv testbench/core/tb_soc.sv
done
cd build/suite
soc0/Vtb_soc +image=smoke.hex
for image in illegal misaligned misaligned-jump; do
    soc0/Vtb_soc "+image=$image.hex" +trap_pc=0
done
soc0/Vtb_soc +image=access-fault.hex +trap_pc=4
soc0/Vtb_soc +image=baseline.hex | tee baseline.log
soc1/Vtb_soc +image=accelerated.hex "$@" | tee accelerated.log
python3 ../../benchmarks/report.py
