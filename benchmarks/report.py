"""Validate simulation digests and report paired measurements."""
import argparse
import csv
import hashlib
from pathlib import Path

LENGTHS = [0, 3, 55, 56, 63, 64, 65, 256, 1024, 4096]


def expected_digest(size):
    if size == 3:
        message = b"abc"
    elif size == 56:
        message = b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    else:
        message = bytes(((i * 73 + (i >> 3) + 19) ^ (i >> 5)) & 255
                        for i in range(size))
    return hashlib.sha256(message).hexdigest()


def read_results(path, accelerated):
    results = {}
    for line in Path(path).read_text().splitlines():
        if not line.startswith("RESULT "):
            continue
        _, size, cycles, rounds, transfers, init, polls, digest = line.split()
        size, cycles, rounds, transfers, init, polls = map(
            int, (size, cycles, rounds, transfers, init, polls))
        if size in results or cycles <= 0 or digest != expected_digest(size):
            raise ValueError(f"{path}: invalid result for {size} bytes")
        blocks = (size + 72) // 64
        if accelerated:
            if (rounds, transfers, init) != (64 * blocks, 16 * blocks + 8, 1) or polls < blocks:
                raise ValueError(f"{path}: invalid accelerator counters for {size} bytes")
        elif any((rounds, transfers, init, polls)):
            raise ValueError(f"{path}: unexpected baseline accelerator activity")
        results[size] = cycles, rounds, transfers, init, polls, digest
    if list(results) != LENGTHS:
        raise ValueError(f"{path}: unexpected case sequence {list(results)}")
    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clock-hz", type=float, default=50_000_000)
    args = parser.parse_args()
    if not 0 < args.clock_hz < float("inf"):
        parser.error("--clock-hz must be positive and finite")
    baseline = read_results("baseline.log", False)
    accelerated = read_results("accelerated.log", True)
    with open("results.csv", "w", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("bytes", "baseline_cycles", "accelerated_cycles", "speedup",
                         "baseline_cycles_per_byte", "accelerated_cycles_per_byte",
                         "baseline_bytes_per_second", "accelerated_bytes_per_second",
                         "clock_hz", "round_cycles", "non_busy_cycles",
                         "data_word_transfers", "init_writes", "status_reads", "digest"))
        for size in LENGTHS:
            sw = baseline[size][0]
            hw, rounds, transfers, init, polls, digest = accelerated[size]
            writer.writerow((size, sw, hw, sw / hw, sw / size if size else "",
                             hw / size if size else "", size * args.clock_hz / sw,
                             size * args.clock_hz / hw, args.clock_hz, rounds,
                             hw - rounds, transfers, init, polls, digest))
            print(f"{size:4} B  software={sw:7} cycles  accelerated={hw:6} cycles  {sw/hw:6.2f}x")
    print("PASS: both configurations matched hashlib for all ten messages")


if __name__ == "__main__":
    main()
