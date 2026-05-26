#!/usr/bin/env python3
"""
Regenerates TimeStack/Resources/Alarm.m4a — the bundled alarm sound.

Two-tone "bee-doo" alternating A5 (880 Hz) / E5 (660 Hz), 1.0s loop with
450ms silence tail for clean looping. Soft 20ms attack/release envelope.
Sine + 15% 3rd-harmonic for bell-like warmth vs pure sine.

Usage:
    python3 gen_alarm.py
    afconvert -d aac -f m4af -b 64000 \
        TimeStack/Resources/Alarm.wav TimeStack/Resources/Alarm.m4a
    rm TimeStack/Resources/Alarm.wav

Per DECISIONS D-030. Tweak parameters here, regenerate, listen-test.
"""

import wave
import math
import struct
import os

SAMPLE_RATE = 44100
DURATION = 1.0
FREQ1 = 880  # A5
FREQ2 = 660  # E5
VOLUME = 0.45

T1_START, T1_END = 0.00, 0.25
T2_START, T2_END = 0.30, 0.55
# 0.55 → 1.00 = silence tail (clean loop point)


def envelope(t, t_start, t_end, fade=0.020):
    if t < t_start or t >= t_end:
        return 0.0
    elapsed = t - t_start
    remaining = t_end - t
    if elapsed < fade:
        return elapsed / fade
    if remaining < fade:
        return remaining / fade
    return 1.0


def tone(t, freq, env):
    return env * (
        0.85 * math.sin(2 * math.pi * freq * t)
        + 0.15 * math.sin(2 * math.pi * 3 * freq * t)
    )


def main():
    n_samples = int(SAMPLE_RATE * DURATION)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        sample = 0.0
        if t < T1_END:
            sample = tone(t, FREQ1, envelope(t, T1_START, T1_END))
        elif t < T2_END:
            sample = tone(t, FREQ2, envelope(t, T2_START, T2_END))
        samples.append(int(sample * VOLUME * 32767))

    script_dir = os.path.dirname(os.path.abspath(__file__))
    out_path = os.path.join(script_dir, "TimeStack", "Resources", "Alarm.wav")
    with wave.open(out_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"Wrote {out_path} ({os.path.getsize(out_path)} bytes, {DURATION}s)")


if __name__ == "__main__":
    main()
