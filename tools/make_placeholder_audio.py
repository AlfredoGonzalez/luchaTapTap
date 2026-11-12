#!/usr/bin/env python3
"""Synthesizes the placeholder sound effects and music loops.

Everything here is generated from scratch by this script (square/triangle/noise
chiptune), so it carries no third-party license: the audio is CC0 and is
credited as such in assets/data/credits.json. Replace any file in
assets/audio/ with the final pick (CC0 or CC-BY only, with a credits entry)
and no code changes; keep the file names.

Usage: python3 tools/make_placeholder_audio.py [output-folder]
Needs numpy and ffmpeg (for the .ogg files).
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio")


def note(n):  # MIDI note number -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def square(freq, t, duty=0.5):
    return np.where((t * freq) % 1.0 < duty, 1.0, -1.0)


def tri(freq, t):
    return 2 * np.abs(2 * ((t * freq) % 1.0) - 1) - 1


def noise(n, rng):
    return rng.uniform(-1, 1, n)


def env(n, attack=0.005, decay=None, sustain=1.0):
    t = np.arange(n) / RATE
    a = np.minimum(t / max(attack, 1e-4), 1.0)
    d = np.exp(-t / decay) if decay else np.ones(n)
    return a * (sustain + (1 - sustain) * d)


def tone(freq, dur, wave_fn=square, decay=0.08, vol=0.5, slide=0.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = freq * (1 + slide * t / max(dur, 1e-3))
    phase_t = np.cumsum(f) / RATE
    # integrate the frequency so slides stay smooth
    sig = wave_fn(1.0, phase_t)
    return sig * env(n, decay=decay) * vol


def seq(parts):
    return np.concatenate(parts)


def silence(dur):
    return np.zeros(int(dur * RATE))


def save(name, data, music=False):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767 * 0.9).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        OUT.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3" if music else "4",
             str(OUT / f"{name}.ogg")],
            check=True,
        )
    print(f"{name}.ogg  {len(data) / RATE:.2f}s")


rng = np.random.default_rng(7)

# --- Effects -------------------------------------------------------------
def thump(dur=0.09, base=170, vol=0.8):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * (base * np.exp(-t * 18)) * t) * np.exp(-t * 35)
    click = noise(n, rng) * np.exp(-t * 90) * 0.5
    return (body + click) * vol


save("sfx_tap", thump(0.07, 190, 0.7))
save("sfx_hit", thump(0.14, 130, 0.9))
crit = thump(0.18, 110, 0.9)
crit[: int(0.12 * RATE)] += tone(880, 0.12, square, 0.05, 0.25)
save("sfx_crit", crit)
save("sfx_buy", seq([tone(note(76), 0.06, square, 0.05, 0.35), tone(note(83), 0.12, square, 0.09, 0.35)]))
save("sfx_error", seq([tone(note(46), 0.09, square, 0.2, 0.4), tone(note(43), 0.14, square, 0.2, 0.4)]))
boss = seq([tone(note(m), 0.16, square, 0.25, 0.4) for m in (40, 40, 43, 46)]) + 0
boss = np.concatenate([boss, tone(note(52), 0.5, square, 0.5, 0.45)])
save("sfx_boss_intro", boss)
save("sfx_victory", seq([tone(note(m), d, square, 0.3, 0.38) for m, d in
                         ((72, 0.1), (76, 0.1), (79, 0.1), (84, 0.35))]))
save("sfx_popup_open", seq([tone(note(72), 0.04, square, 0.05, 0.3), tone(note(79), 0.07, square, 0.07, 0.3)]))
save("sfx_popup_close", seq([tone(note(79), 0.04, square, 0.05, 0.3), tone(note(72), 0.07, square, 0.07, 0.3)]))
save("sfx_finisher", thump(0.3, 90, 1.0) + tone(660, 0.3, square, 0.2, 0.3, slide=1.0))


# --- Music ---------------------------------------------------------------
def music(bpm, bars, chords, melody, bass_wave=tri, lead_duty=0.25, name="music"):
    beat = 60.0 / bpm
    step = beat / 2  # eighth notes
    total = int(bars * 8 * step * RATE)
    out = np.zeros(total)

    def add(start_step, sig):
        i = int(start_step * step * RATE)
        j = min(total, i + len(sig))
        out[i:j] += sig[: j - i]

    for bar in range(bars):
        root = chords[bar % len(chords)]
        for s in range(8):
            pos = bar * 8 + s
            # bass on the beat, octave jump on the off-beat
            bnote = root - 12 + (12 if s % 2 else 0)
            add(pos, tone(note(bnote), step * 0.9, bass_wave, 0.25, 0.30))
            m = melody[(bar * 8 + s) % len(melody)]
            if m is not None:
                add(pos, tone(note(root + m), step * 0.85, lambda f, t: square(f, t, lead_duty), 0.15, 0.20))
        # drums: kick on 1 and 3 beats, hat on off-beats
        for s in (0, 4):
            add(bar * 8 + s, thump(0.08, 120, 0.45))
        for s in (2, 6):
            add(bar * 8 + s, noise(int(0.05 * RATE), rng) * np.exp(-np.arange(int(0.05 * RATE)) / RATE * 70) * 0.25)
    return out


main = music(
    bpm=132, bars=8,
    chords=[57, 53, 48, 55, 57, 53, 48, 55],
    melody=[12, None, 16, 19, 12, None, 7, 9, 12, 16, None, 19, 24, 19, 16, None,
            9, None, 12, 16, 9, None, 5, 7, 11, 14, None, 17, 19, 17, 14, None],
    name="main",
)
save("music_main", main, music=True)

boss_music = music(
    bpm=156, bars=8,
    chords=[52, 52, 55, 53, 52, 52, 58, 57],
    melody=[12, 12, None, 15, 12, None, 17, 15, 12, 12, None, 19, 18, None, 15, 12,
            10, 10, None, 13, 10, None, 15, 13, 12, None, 15, 17, 19, 17, 15, None],
    lead_duty=0.125, name="boss",
)
save("music_boss", boss_music, music=True)
