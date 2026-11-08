#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
for tool in verilator make g++; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Missing %s. On Ubuntu, install Verilator 5.x and build-essential.\n' "$tool" >&2
        exit 127
    fi
done

mkdir -p build/alu
cd build/alu
verilator --binary --timing --assert --trace --timescale 1ns/1ps -Wall \
    --top-module tb_alu ../../rtl/core/alu.sv ../../testbench/core/tb_alu.sv
./obj_dir/Vtb_alu "$@"
