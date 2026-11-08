# Verified benchmark results

The local run used Ubuntu 24.04 in Docker on Windows, Verilator 5.020, RISC-V GCC 13.2.0, and Yosys 0.33. The ALU passed all 40 checks. The register file and decoder unit tests, bare-metal assembly smoke test, four fault cases, and accelerator reset and empty-message tests passed. Both C firmware variants produced the expected SHA-256 digest for all ten messages. The suite also checked the round and transfer counts and generated a VCD trace.

| Input bytes | Software cycles | Accelerated cycles | Speedup |
| ---: | ---: | ---: | ---: |
| 0 | 10,559 | 593 | 17.81× |
| 3 | 10,660 | 694 | 15.36× |
| 55 | 12,272 | 2,306 | 5.32× |
| 56 | 22,629 | 2,732 | 8.28× |
| 63 | 22,846 | 2,949 | 7.75× |
| 64 | 21,315 | 1,420 | 15.01× |
| 65 | 21,354 | 1,459 | 14.64× |
| 256 | 53,559 | 3,829 | 13.99× |
| 1,024 | 182,535 | 13,465 | 13.56× |
| 4,096 | 698,439 | 52,009 | 13.43× |

At the assumed 50 MHz, the 4 KiB case moved from 170.52 to 12.70 cycles per byte and from 0.293 to 3.94 MB/s. The accelerated run spent 4,160 cycles in the SHA engine and 47,849 cycles outside its busy interval. It performed one INIT write, 65 START writes, 1,048 data word transfers and 650 status reads. Each access takes one bus cycle in this harness, with additional CPU instruction overhead. Status polling can overlap engine work.

The 55- and 63-byte tails require the firmware's byte-at-a-time padding loop. The 64-byte case can use the full-block packing loop and a separate padding-only block. This accounts for the accelerated cycle count dropping at 64 bytes despite processing the same number of compression blocks as the 63-byte case.

| Configuration | Generic cells | Flip-flop cells |
| --- | ---: | ---: |
| Baseline | 6,748 | 1,138 |
| Accelerated | 14,212 | 2,201 |
| Increase | 7,464 | 1,063 |

The accelerator more than doubled the generic cell count. Whether that overhead is acceptable depends on the target logic budget. The counts exclude external RAM, and the throughput estimate assumes the same clock for both configurations. See [methodology](architecture.md) and [full benchmark CSV](../benchmarks/measured-results.csv).
