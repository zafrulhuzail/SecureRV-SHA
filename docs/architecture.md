# Architecture and measurement

## CPU

The reset PC is zero. The controller in `cpu.sv` progresses through fetch, execute and, for data accesses, a separate memory state. It shares one ordered request interface for instructions and data. The target acknowledges a transaction with `ready`, returns `rdata` for reads, and may assert `error` on the acknowledged cycle. Writes use byte lanes selected by `wstrb`. The address retains the byte offset, and read data is returned as an aligned 32-bit little-endian word. The CPU stalls until acknowledgment. The supplied harness acknowledges immediately.

The register file provides two combinational reads and one synchronous write. Reads of x0 return zero, and writes to x0 are discarded. Other register contents are unspecified at reset. The decoder checks encodings and assembles I, S, B, U and J immediates. The ALU's 4-bit internal selectors 0–8 select ADD, SUB, AND, OR, XOR, SLL, SRL, SLT and SLTU respectively. Arithmetic wraps modulo 2³². Logical shifts use the low five bits of the second operand. Signed comparison interprets operands as two's-complement integers. Unassigned ALU selectors produce zero. The CPU implements SRA on a separate arithmetic-right-shift path selected by decoder value 9.

The bare-metal execution environment supports RV32I arithmetic, comparisons, jumps, branches, loads and stores. FENCE retires on the ordered bus. ECALL, EBREAK, illegal encodings, misaligned accesses, misaligned taken targets and bus errors stop the CPU in the trap state. The PC holds the faulting instruction. There is no privileged mode, exception handler, CSR block, interrupts or compressed extension. The directed tests exercise instruction behavior but are not a formal ISA conformance suite. [RV32I specification](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html)

The synthesizable `secure_soc` wrapper selects the baseline or accelerated configuration with its `ACCEL` parameter. It routes accelerator requests internally and forwards all other requests to the external bus.

The simulator uses 128 KiB of byte-addressed RAM at zero and seeds its contents from the linked firmware binary. The host instrumentation is at `0x20000000`. A write to offset zero terminates the simulation with the firmware exit status. Other host offsets report measurement boundaries and digest words. These ports and the RAM model live in the testbench.

## SHA-256 MMIO

The accelerator is mapped at `0x10000000`. Use aligned 32-bit accesses.

| Offset | Access | Meaning |
| --- | --- | --- |
| `0x00` | R | Bit 0 is busy |
| `0x00` | W | Value 1 restores the initial digest state. Value 2 starts a block |
| `0x20–0x5c` | W | Sixteen input words, first message byte in bits 31–24 of word 0 |
| `0x60–0x7c` | R | Eight digest words in SHA-256 order |

Write INIT once per message and fill all sixteen words before each START. Wait until busy clears before filling the next block or reading the completed digest. Writes while busy are ignored. Reset aborts the current block and restores the IV. The caller must refill the message words after reset or before each new block. Digest reads while busy expose the last committed state. The accelerator computes one round per cycle using sixteen schedule registers and adds the final round state to the chaining state on cycle 64.

The firmware performs all padding for both configurations. It appends a one bit, then enough zeros to reach byte 56 of the last block, then the original bit length as a 64-bit big-endian value. It emits an extra block when the residual message contains at least 56 bytes. The API accepts a byte length representable in 32 bits. [FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)

## Benchmark boundaries

The host markers bracket each call to the hash function. Counts include function overhead, initialization, byte packing, padding, CPU memory traffic, and, in the accelerated build, MMIO and polling. Input generation and digest reporting are outside the interval. Both builds use the same input bytes and zero-wait-state RAM. The CPU and accelerator advance on the same simulated clock. The measured speedup is baseline cycles divided by accelerated cycles.

The report separately counts accelerator busy cycles, data word transfers, INIT writes and status reads. Each acknowledged MMIO transfer consumes one memory-state cycle in this model. Instruction fetch, execution and software loop overhead contribute additional cycles. Polling overlaps busy cycles, so these counts cannot be added to obtain total cycles. Non-busy cycles include all work outside the compression rounds. Cycles per byte is undefined for the empty message. The throughput estimate uses an assumed clock and no timing closure result.

The Yosys script synthesizes both configurations of the SoC wrapper using generic cells. Counts include the CPU, its register file and, for the accelerated configuration, the MMIO decode and SHA engine. The external RAM and testbench instrumentation are excluded. Flip-flop counts and cell totals describe relative complexity under this mapping and do not establish area, power or attainable frequency. Side-channel behavior and silicon performance are outside the scope of these experiments.
