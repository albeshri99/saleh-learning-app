"""Copy a frame-aligned prefix from an MP3 without re-encoding it."""

from __future__ import annotations

import argparse
from pathlib import Path


BITRATES = {
    "mpeg1_l3": [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    "mpeg2_l3": [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}
SAMPLE_RATES = {
    3: [44100, 48000, 32000],
    2: [22050, 24000, 16000],
    0: [11025, 12000, 8000],
}


def synchsafe(value: bytes) -> int:
    return sum((byte & 0x7F) << shift for byte, shift in zip(value, (21, 14, 7, 0)))


def clip(source: Path, target: Path, seconds: float) -> float:
    data = source.read_bytes()
    offset = 0
    prefix = b""
    if data.startswith(b"ID3") and len(data) >= 10:
        tag_size = 10 + synchsafe(data[6:10])
        prefix = data[:tag_size]
        offset = tag_size

    frames: list[bytes] = []
    duration = 0.0
    while offset + 4 <= len(data) and duration < seconds:
        header = int.from_bytes(data[offset : offset + 4], "big")
        if header & 0xFFE00000 != 0xFFE00000:
            offset += 1
            continue
        version = (header >> 19) & 0x3
        layer = (header >> 17) & 0x3
        bitrate_index = (header >> 12) & 0xF
        sample_index = (header >> 10) & 0x3
        padding = (header >> 9) & 0x1
        if version == 1 or layer != 1 or bitrate_index in (0, 15) or sample_index == 3:
            offset += 1
            continue

        sample_rate = SAMPLE_RATES[version][sample_index]
        bitrate_table = BITRATES["mpeg1_l3" if version == 3 else "mpeg2_l3"]
        bitrate = bitrate_table[bitrate_index] * 1000
        frame_size = (
            (144 * bitrate // sample_rate) + padding
            if version == 3
            else (72 * bitrate // sample_rate) + padding
        )
        if frame_size <= 4 or offset + frame_size > len(data):
            break
        frames.append(data[offset : offset + frame_size])
        duration += (1152 if version == 3 else 576) / sample_rate
        offset += frame_size

    if not frames:
        raise ValueError(f"No MPEG Layer III frames found in {source}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(prefix + b"".join(frames))
    return duration


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--seconds", type=float, required=True)
    args = parser.parse_args()
    actual = clip(args.source, args.target, args.seconds)
    print(f"wrote {args.target} ({actual:.3f}s of MPEG audio)")


if __name__ == "__main__":
    main()
