#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
mkdir -p build/synth
for config in baseline accelerated; do
    accel=0
    if [[ $config == accelerated ]]; then accel=1; fi
    report="build/synth/$config.log"
    yosys -Q -p "read_verilog -sv rtl/core/*.sv rtl/sha256/*.sv rtl/secure_soc.sv;
        chparam -set ACCEL $accel secure_soc; synth -top secure_soc -flatten; stat" > "$report"
    echo "$report"
    sed -n '/Printing statistics/,$p' "$report" | tail -n 30
done
