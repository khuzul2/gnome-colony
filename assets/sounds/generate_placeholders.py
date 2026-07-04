#!/usr/bin/env python3
"""Deterministic placeholder-sound generator for Gnome Colony (T19.1).

Synthesizes the placeholder WAVs listed in SPECS below: 16-bit PCM mono,
22050 Hz, 0.3-6 s each. Fully deterministic: every random stream is seeded
from the target file name (crc32), no wall-clock anywhere. Re-running
always reproduces byte-identical files.

Five sounds are NOT generated here (real CC0/CC-BY recordings, see
SOURCES.md): phenomenon_weeping_sky, phenomenon_landslide,
phenomenon_coming_herd, phenomenon_thing_in_dark, phenomenon_birds_silent.

Usage: python3 assets/sounds/generate_placeholders.py  (needs numpy)
"""

import os
import wave
import zlib

import numpy as np

SR = 22050
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------- utilities
def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode("utf-8")))


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(round(SR * dur))) / SR


def sine(freq, t, phase=0.0):
    return np.sin(2 * np.pi * freq * t + phase)


def fade(x: np.ndarray, fin: float = 0.01, fout: float = 0.05) -> np.ndarray:
    x = x.copy()
    ni, no = int(SR * fin), int(SR * fout)
    ni, no = min(ni, len(x)), min(no, len(x))
    if ni > 0:
        x[:ni] *= np.linspace(0.0, 1.0, ni)
    if no > 0:
        x[-no:] *= np.linspace(1.0, 0.0, no)
    return x


def bandpass(x: np.ndarray, lo: float, hi: float, soft: float = 0.25) -> np.ndarray:
    """FFT brickwall-ish bandpass with soft (raised-cosine) edges."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    mask = np.ones_like(freqs)
    lo_w = max(lo * soft, 1.0)
    hi_w = max(hi * soft, 1.0)
    mask *= 0.5 * (1 + np.tanh((freqs - lo) / lo_w))
    mask *= 0.5 * (1 - np.tanh((freqs - hi) / hi_w))
    return np.fft.irfft(spec * mask, n=len(x))


def norm(x: np.ndarray, peak: float = 0.7) -> np.ndarray:
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-12 else x


def brown(rng, n):
    x = np.cumsum(rng.standard_normal(n))
    x -= np.linspace(x[0], x[-1], n)  # detrend so it loops-ish / no DC ramp
    return norm(x, 1.0)


def decay_env(t, tau):
    return np.exp(-t / tau)


def bell(t, f0, partials, tau, rng=None, inharm=0.0):
    """Sum of decaying partials; inharm skews ratios away from integers."""
    out = np.zeros_like(t)
    for i, (ratio, amp) in enumerate(partials):
        r = ratio * (1 + inharm * i * i)
        out += amp * sine(f0 * r, t) * decay_env(t, tau / (1 + 0.7 * i))
    return out


def chime(t, freqs, tau=0.4, stagger=0.0):
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        d = int(SR * stagger * i)
        seg = t[: len(t) - d]
        out[d:] += sine(f, seg) * decay_env(seg, tau) / (1 + 0.3 * i)
    return out


def crackle(rng, n, density, band=(800, 4000), tau=0.004):
    """Sparse impulse train -> bandpass = dry crackling."""
    x = np.zeros(n)
    hits = rng.random(n) < density / SR
    x[hits] = rng.uniform(-1, 1, hits.sum())
    kernel_t = np.arange(int(SR * tau * 6)) / SR
    kernel = np.exp(-kernel_t / tau)
    x = np.convolve(x, kernel)[:n]
    return bandpass(x, *band)


# ---------------------------------------------------------- sound builders
def snd_still_air(name):
    # sudden pressure-drop hush: airy hiss that thins out to nothing
    rng = rng_for(name)
    t = t_axis(4.0)
    hiss = bandpass(rng.standard_normal(len(t)), 3000, 9000)
    thin = np.linspace(1.0, 0.05, len(t)) ** 2
    body = hiss * thin * 0.5
    drop = sine(220, t) * decay_env(t, 0.15) * 0.25  # soft initial "blink"
    return fade(norm(body + drop, 0.4), 0.005, 1.5)


def snd_long_dark(name):
    # low drone: detuned deep sines, slow breathing LFO
    t = t_axis(6.0)
    lfo = 0.75 + 0.25 * sine(0.15, t)
    d = sine(55, t) + 0.8 * sine(55.7, t) + 0.5 * sine(36.7, t) + 0.3 * sine(110.3, t)
    return fade(norm(d * lfo, 0.6), 0.8, 1.2)


def snd_ground_remembers(name):
    # deep rumble swell
    rng = rng_for(name)
    t = t_axis(5.0)
    rum = bandpass(brown(rng, len(t)), 18, 75)
    swell = np.sin(np.pi * t / t[-1]) ** 1.5
    throb = 1 + 0.3 * sine(2.1, t)
    return fade(norm(rum * swell * throb, 0.75), 0.3, 0.8)


def snd_standing_stones(name):
    # stone scrape: gritty midband noise with juddering drag
    rng = rng_for(name)
    t = t_axis(2.5)
    grit = bandpass(rng.standard_normal(len(t)), 180, 950)
    judder = 0.6 + 0.4 * np.abs(sine(13, t) * sine(2.9, t))
    drag = np.concatenate(
        [np.linspace(0.2, 1.0, len(t) // 3), np.ones(len(t) - len(t) // 3)]
    )
    grind = crackle(rng, len(t), 220, band=(300, 1600), tau=0.002)
    return fade(norm((grit * judder + 0.7 * grind) * drag, 0.7), 0.05, 0.4)


def snd_the_swallowing(name):
    # earth collapse: descending rumble sweep + debris impacts
    rng = rng_for(name)
    t = t_axis(4.0)
    n = len(t)
    sweep_f = np.linspace(120, 25, n)
    phase = 2 * np.pi * np.cumsum(sweep_f) / SR
    groan = np.sin(phase) * np.linspace(0.4, 1.0, n)
    rum = bandpass(brown(rng, n), 20, 90) * np.linspace(0.5, 1.0, n)
    debris = crackle(rng, n, 90, band=(120, 900), tau=0.01)
    debris *= np.clip(np.sin(np.pi * (t / t[-1]) ** 0.7), 0, 1)
    return fade(norm(0.8 * rum + 0.5 * groan + 0.6 * debris, 0.8), 0.1, 1.0)


def snd_the_quickening(name):
    # lush shimmer: bright pentatonic cluster, gentle chorus swell
    rng = rng_for(name)
    t = t_axis(5.0)
    base = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]  # C maj pentatonic
    out = np.zeros_like(t)
    for f in base:
        for det in (0.997, 1.0, 1.004):
            ph = rng.uniform(0, 2 * np.pi)
            trem = 1 + 0.3 * sine(rng.uniform(0.8, 2.0), t, rng.uniform(0, 6))
            out += sine(f * det, t, ph) * trem / (f / 523.25)
    swell = np.sin(np.pi * t / t[-1]) ** 0.8
    return fade(norm(out * swell, 0.45), 0.6, 1.2)


def snd_the_blight(name):
    # dry decay: brittle crackle sinking, hollow dark undertone
    rng = rng_for(name)
    t = t_axis(4.0)
    n = len(t)
    dry = crackle(rng, n, 160, band=(700, 3500), tau=0.003)
    dry *= np.linspace(1.0, 0.25, n)
    sink_f = np.linspace(196, 92, n)
    under = np.sin(2 * np.pi * np.cumsum(sink_f) / SR) * 0.35
    husk = bandpass(rng.standard_normal(n), 250, 700) * 0.2
    return fade(norm(dry + under + husk, 0.55), 0.05, 1.0)


def snd_wrongness_blood(name):
    # unsettling pulse: slow heart-like double thump + sour minor-2nd drone
    rng = rng_for(name)
    t = t_axis(5.0)
    n = len(t)
    thump = np.zeros(n)
    beat = 0.9  # seconds per heartbeat
    for k in range(int(5.0 / beat)):
        for off, amp in ((0.0, 1.0), (0.16, 0.6)):
            i = int((k * beat + off) * SR)
            if i < n:
                seg = t[: n - i]
                thump[i:] += amp * sine(52, seg) * decay_env(seg, 0.09)
    sour = (sine(233.08, t) + sine(246.94, t)) * 0.12 * (0.6 + 0.4 * sine(0.4, t))
    return fade(norm(thump + sour, 0.7), 0.1, 0.8)


def snd_shared_dream(name):
    # ethereal wash: glassy gliding tones in a soft noise halo
    rng = rng_for(name)
    t = t_axis(6.0)
    n = len(t)
    halo = bandpass(rng.standard_normal(n), 400, 2400) * 0.12
    out = np.zeros(n)
    for f0, f1 in ((392, 440), (587.33, 554.37), (784, 830.6)):
        glide = np.linspace(f0, f1, n)
        ph = 2 * np.pi * np.cumsum(glide) / SR
        out += np.sin(ph + rng.uniform(0, 6)) * (0.5 + 0.5 * sine(0.23, t, rng.uniform(0, 6)))
    swell = np.sin(np.pi * t / t[-1]) ** 0.6
    return fade(norm((out * 0.3 + halo) * swell, 0.4), 1.0, 1.5)


def snd_day_twice(name):
    # vast alien tone: huge inharmonic partial stack, slow beating
    t = t_axis(6.0)
    partials = [(1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.93, 0.2), (13.34, 0.1)]
    out = bell(t, 49, partials, 7.0, inharm=0.004)
    out += 0.4 * sine(49 * 1.02, t) * decay_env(t, 5.0)  # slow beat against root
    return fade(norm(out, 0.65), 0.02, 1.5)


def snd_consequence_unease(name):
    t = t_axis(2.2)
    swell = np.sin(np.pi * t / t[-1]) ** 2
    d = sine(110, t) + sine(155.56, t) * 0.8  # tritone
    return fade(norm(d * swell, 0.5), 0.2, 0.5)


def snd_consequence_flood(name):
    rng = rng_for(name)
    t = t_axis(3.0)
    n = len(t)
    rise = np.linspace(0, 1, n)
    lo = 200 + 500 * rise
    wash = np.zeros(n)
    win = int(SR * 0.5)
    noise = rng.standard_normal(n)
    for i in range(0, n, win):  # rising band sweep, chunked
        j = min(i + win, n)
        wash[i:j] = bandpass(noise[i:j], lo[i], lo[i] * 4, soft=0.4)[: j - i]
    burble = crackle(rng, n, 60, band=(300, 1200), tau=0.02)
    return fade(norm(wash * (0.3 + 0.7 * rise) + 0.5 * burble, 0.6), 0.3, 0.5)


def snd_consequence_dam_flood(name):
    rng = rng_for(name)
    t = t_axis(3.2)
    n = len(t)
    burst = bandpass(rng.standard_normal(n), 80, 2500) * decay_env(t, 0.8)
    surge = bandpass(brown(rng, n), 40, 300) * np.linspace(1.0, 0.4, n)
    crack = crackle(rng, n, 40, band=(500, 2000), tau=0.015) * decay_env(t, 1.2)
    return fade(norm(burst + surge + crack, 0.75), 0.005, 0.8)


def snd_consequence_famine(name):
    t = t_axis(2.6)
    seq = [(220.0, 0.0), (196.0, 0.7), (164.81, 1.4)]  # hollow falling minor
    out = np.zeros_like(t)
    for f, at in seq:
        i = int(at * SR)
        seg = t[: len(t) - i]
        out[i:] += (sine(f, seg) + 0.4 * sine(f * 2, seg)) * decay_env(seg, 0.5)
    return fade(norm(out * 0.6, 0.5), 0.01, 0.6)


def snd_consequence_migration(name):
    rng = rng_for(name)
    t = t_axis(3.0)
    n = len(t)
    out = np.zeros(n)
    step = 0.42
    k = 0
    while step * k < 3.0:
        i = int(step * k * SR)
        seg = t[: n - i]
        f = 70 + rng.uniform(-6, 6)
        out[i:] += sine(f, seg) * decay_env(seg, 0.06) * (1.0 - 0.25 * k / 8)
        k += 1
    out *= np.linspace(1.0, 0.15, n)  # walking away
    return fade(norm(out, 0.6), 0.01, 0.6)


def snd_consequence_quake(name):
    rng = rng_for(name)
    t = t_axis(3.0)
    n = len(t)
    jolt = bandpass(brown(rng, n), 15, 120) * decay_env(t, 0.5)
    after = bandpass(brown(rng_for(name + "#2"), n), 20, 80)
    after *= decay_env(np.maximum(t - 1.4, 0), 0.5) * (t > 1.4) * 0.5
    rattle = crackle(rng, n, 80, band=(200, 1000), tau=0.008) * decay_env(t, 0.7)
    return fade(norm(jolt + after + 0.4 * rattle, 0.8), 0.002, 0.6)


def snd_consequence_cursed_place(name):
    rng = rng_for(name)
    t = t_axis(3.0)
    n = len(t)
    rev = np.linspace(0, 1, n) ** 3  # reverse-swell
    chord = sine(146.83, t) + sine(155.56, t) + 0.6 * sine(220, t)  # dark cluster
    breath = bandpass(rng.standard_normal(n), 150, 600) * 0.25
    x = (chord * 0.4 + breath) * rev
    tail = int(0.35 * SR)
    x[-tail:] *= np.linspace(1, 0, tail)  # sudden choke-off
    return norm(fade(x, 0.05, 0.02), 0.55)


def snd_consequence_soil_exhaustion(name):
    rng = rng_for(name)
    t = t_axis(2.0)
    crumb = crackle(rng, len(t), 260, band=(400, 2200), tau=0.004)
    dust = bandpass(rng.standard_normal(len(t)), 800, 2600) * 0.15
    env = np.linspace(1.0, 0.1, len(t))
    return fade(norm((crumb + dust) * env, 0.5), 0.01, 0.5)


def snd_consequence_scapegoat_schism(name):
    t = t_axis(3.0)
    n = len(t)
    up = np.linspace(261.63, 329.63, n)
    dn = np.linspace(261.63, 207.65, n)  # unison tears apart
    a = np.sin(2 * np.pi * np.cumsum(up) / SR)
    b = np.sin(2 * np.pi * np.cumsum(dn) / SR)
    snap = sine(1200, t) * decay_env(t, 0.02) * 0.5
    return fade(norm((a + b) * 0.35 + snap, 0.5), 0.05, 0.7)


def snd_consequence_medicine(name):
    t = t_axis(2.0)
    out = chime(t, [523.25, 659.25, 783.99], tau=0.5, stagger=0.18)
    warm = sine(261.63, t) * decay_env(t, 0.8) * 0.3
    return fade(norm(out + warm, 0.5), 0.005, 0.5)


def snd_consequence_predator_follows(name):
    rng = rng_for(name)
    t = t_axis(3.0)
    n = len(t)
    stalk = np.zeros(n)
    for k in range(4):
        i = int(k * 0.7 * SR)
        seg = t[: n - i]
        stalk[i:] += sine(48, seg) * decay_env(seg, 0.12) * 0.8
    snarl = bandpass(rng.standard_normal(n), 90, 260) * (0.5 + 0.5 * sine(23, t))
    snarl *= np.sin(np.pi * t / t[-1]) ** 2 * 0.5
    return fade(norm(stalk + snarl, 0.6), 0.05, 0.6)


def snd_consequence_hunt_heroism(name):
    t = t_axis(2.5)
    out = np.zeros_like(t)
    for f, at in ((196.0, 0.0), (293.66, 0.25), (392.0, 0.5)):  # rising fifth+octave
        i = int(at * SR)
        seg = t[: len(t) - i]
        for h, a in ((1, 1.0), (2, 0.5), (3, 0.33), (4, 0.2)):  # brassy
            out[i:] += a * sine(f * h, seg) * decay_env(seg, 0.6)
    return fade(norm(out, 0.55), 0.01, 0.6)


def snd_consequence_rite_crystallizes(name):
    t = t_axis(3.0)
    arp = chime(t, [440, 554.37, 659.25, 880], tau=0.35, stagger=0.14)
    lock = (sine(440, t) + sine(554.37, t) + sine(659.25, t)) / 3
    gate = np.clip((t - 1.2) / 0.4, 0, 1) * decay_env(np.maximum(t - 1.2, 0), 1.0)
    return fade(norm(arp + lock * gate * 0.8, 0.5), 0.005, 0.7)


def snd_consequence_schism_seed(name):
    t = t_axis(2.5)
    n = len(t)
    det = np.linspace(0, 6, n)  # one voice slowly goes sour
    ph = 2 * np.pi * np.cumsum(329.63 + det) / SR
    x = sine(329.63, t) + np.sin(ph)
    return fade(norm(x * 0.4, 0.45), 0.1, 0.6)


def snd_consequence_mass_conversion(name):
    rng = rng_for(name)
    t = t_axis(3.5)
    out = np.zeros_like(t)
    for f in (130.81, 196.0, 261.63, 329.63, 392.0):
        for _ in range(3):  # loose "many voices" unison
            d = rng.uniform(0.995, 1.005)
            out += sine(f * d, t, rng.uniform(0, 6)) / (f / 130.81)
    swell = np.sin(np.pi * t / t[-1]) ** 1.2
    return fade(norm(out * swell, 0.5), 0.4, 0.9)


def snd_consequence_heresy_schism(name):
    t = t_axis(3.0)
    n = len(t)
    half = int(1.2 * SR)
    pure = sine(261.63, t) + sine(329.63, t) + sine(392.0, t)
    riven = sine(261.63, t) + sine(311.13, t) + sine(370.0, t)  # curdles
    mix = np.where(np.arange(n) < half, pure, riven)
    crack_t = t[: n - half]
    crack = np.zeros(n)
    crack[half:] = sine(900, crack_t) * decay_env(crack_t, 0.03) * 0.6
    return fade(norm(mix * 0.3 + crack, 0.5), 0.05, 0.8)


def snd_event_born(name):
    t = t_axis(1.2)
    return fade(norm(chime(t, [880, 1318.5], tau=0.35, stagger=0.1), 0.5), 0.003, 0.4)


def snd_event_died(name):
    t = t_axis(3.0)
    partials = [(1.0, 1.0), (2.0, 0.5), (2.98, 0.35), (4.2, 0.15)]
    return fade(norm(bell(t, 98, partials, 2.2), 0.6), 0.002, 0.8)


def snd_event_stage_changed(name):
    t = t_axis(1.5)
    return fade(norm(chime(t, [392, 523.25, 659.25], tau=0.4, stagger=0.12), 0.5), 0.005, 0.4)


def snd_event_knowledge_lost(name):
    t = t_axis(2.0)
    n = len(t)
    gl = np.linspace(830.6, 415.3, n)  # a thought slipping away
    x = np.sin(2 * np.pi * np.cumsum(gl) / SR) * np.linspace(0.8, 0.0, n)
    whisper = bandpass(rng_for(name).standard_normal(n), 1500, 4000)
    whisper *= np.linspace(0.15, 0.0, n)
    return fade(norm(x + whisper, 0.45), 0.02, 0.6)


def snd_event_belief_formed(name):
    t = t_axis(2.0)
    bloom = (sine(261.63, t) + sine(329.63, t) + sine(392.0, t)) / 3
    env = np.sin(np.pi * t / t[-1]) ** 0.7
    glint = sine(1046.5, t) * decay_env(np.maximum(t - 0.5, 0), 0.3) * (t > 0.5) * 0.3
    return fade(norm(bloom * env + glint, 0.5), 0.15, 0.6)


def snd_event_main_settlement_changed(name):
    t = t_axis(1.6)
    out = np.zeros_like(t)
    for f, at in ((329.63, 0.0), (493.88, 0.3)):  # heraldic two-tone
        i = int(at * SR)
        seg = t[: len(t) - i]
        for h, a in ((1, 1.0), (2, 0.4), (3, 0.25)):
            out[i:] += a * sine(f * h, seg) * decay_env(seg, 0.45)
    return fade(norm(out, 0.5), 0.005, 0.45)


def snd_event_world_ended(name):
    t = t_axis(6.0)
    partials = [(1.0, 1.0), (2.0, 0.55), (2.92, 0.4), (4.15, 0.2), (5.9, 0.1)]
    out = np.zeros_like(t)
    for k, amp in ((0, 1.0), (1, 0.75), (2, 0.55)):  # three fading tolls
        i = int(k * 1.9 * SR)
        seg = t[: len(t) - i]
        out[i:] += bell(seg, 65.4, partials, 2.6) * amp
    return fade(norm(out, 0.7), 0.002, 1.8)


def snd_event_settlement_founded(name):
    rng = rng_for(name)
    t = t_axis(1.6)
    thump = sine(65, t) * decay_env(t, 0.12)  # stake driven into earth
    knock = bandpass(rng.standard_normal(len(t)), 300, 900) * decay_env(t, 0.04)
    warm = (sine(196, t) + sine(293.66, t)) * decay_env(np.maximum(t - 0.15, 0), 0.6) * 0.4
    return fade(norm(thump + 0.5 * knock + warm, 0.6), 0.002, 0.4)


def snd_event_discovery(name):
    t = t_axis(1.5)
    arp = chime(t, [659.25, 830.6, 987.77, 1318.5], tau=0.3, stagger=0.08)
    return fade(norm(arp, 0.5), 0.003, 0.4)


def snd_event_fracture(name):
    rng = rng_for(name)
    t = t_axis(2.0)
    snapc = crackle(rng, len(t), 500, band=(900, 5000), tau=0.002) * decay_env(t, 0.12)
    ringing = (sine(587.33, t) + sine(622.25, t)) * decay_env(t, 0.9) * 0.35
    return fade(norm(snapc * 1.2 + ringing, 0.6), 0.001, 0.5)


def snd_event_war(name):  # T22.3: harsh low brass-like clash swell
    rng = rng_for(name)
    t = t_axis(2.0)
    n = len(t)
    out = np.zeros(n)
    for f in (73.42, 77.78, 110.0):  # D2 against Eb2 rub, A2 on top
        for h in range(1, 8):  # bright harmonic stack = brassy rasp
            out += sine(f * h, t, rng.uniform(0, 6)) / (h**1.1)
    swell = np.linspace(0.2, 1.0, n) ** 2
    growl = 1 + 0.35 * sine(19, t)
    clash = bandpass(rng.standard_normal(n), 700, 2600)
    clash *= decay_env(np.maximum(t - 1.25, 0), 0.18) * (t > 1.25) * 0.9
    return fade(norm(out * swell * growl * 0.25 + clash, 0.7), 0.02, 0.4)


def snd_event_schism(name):  # T22.3: a held chord tearing apart
    rng = rng_for(name)
    t = t_axis(2.0)
    n = len(t)
    tear = np.clip((t - 0.7) / 1.1, 0.0, 1.0) ** 1.5
    out = np.zeros(n)
    # C-E-G holds, then E bends down to Eb and G up to A — riven.
    for f0, drift in ((261.63, 0.0), (329.63, -0.056), (392.0, 0.122)):
        freq = f0 * (1.0 + drift * tear)
        ph = 2 * np.pi * np.cumsum(freq) / SR
        out += np.sin(ph + rng.uniform(0, 6))
    snap = sine(1400, t) * decay_env(np.maximum(t - 0.7, 0), 0.02) * (t > 0.7) * 0.8
    body = out * (0.85 + 0.15 * sine(5.3, t) * tear)
    return fade(norm(body * 0.3 + snap, 0.55), 0.02, 0.4)


def _season_bed(name, tone_fn, noise_band, noise_amp, dur=6.0):
    rng = rng_for(name)
    t = t_axis(dur)
    n = len(t)
    bed = bandpass(rng.standard_normal(n), *noise_band) * noise_amp
    gust = 0.7 + 0.3 * sine(0.19, t, rng.uniform(0, 6)) * sine(0.07, t, rng.uniform(0, 6))
    return fade(norm(bed * gust + tone_fn(t, rng), 0.35), 0.8, 0.8)


def snd_ambience_season_0(name):  # spring: airy bed + light bird-ish blips
    def tone(t, rng):
        out = np.zeros_like(t)
        n = len(t)
        for _ in range(9):
            at = rng.uniform(0.3, 5.2)
            f = rng.uniform(2200, 3800)
            i = int(at * SR)
            seg = t[: n - i]
            warble = np.sin(2 * np.pi * (f + 150 * np.sin(2 * np.pi * 27 * seg)) * seg)
            out[i:] += warble * decay_env(seg, 0.05) * 0.12
        return out

    return _season_bed(name, tone, (900, 3200), 0.35)


def snd_ambience_season_1(name):  # summer: warm bed + insect drone shimmer
    def tone(t, rng):
        buzz = sine(180, t) * (0.5 + 0.5 * np.clip(sine(31, t), 0, 1)) * 0.1
        heat = sine(4200, t) * (0.5 + 0.5 * sine(7.3, t)) * 0.04
        return buzz + heat

    return _season_bed(name, tone, (500, 1800), 0.4)


def snd_ambience_season_2(name):  # autumn: rustling leaves, gusty
    def tone(t, rng):
        rustle = crackle(rng, len(t), 320, band=(1200, 5000), tau=0.002)
        return rustle * (0.4 + 0.6 * np.clip(sine(0.31, t, 1.0), 0, 1)) * 0.5

    return _season_bed(name, tone, (700, 2600), 0.45)


def snd_ambience_season_3(name):  # winter wind: whistling gusts
    rng = rng_for(name)
    t = t_axis(6.0)
    n = len(t)
    noise = rng.standard_normal(n)
    center = 700 + 500 * np.sin(2 * np.pi * 0.11 * t + 1.0) * np.sin(2 * np.pi * 0.043 * t)
    win = int(SR * 0.4)
    wind = np.zeros(n)
    for i in range(0, n, win):
        j = min(i + win, n)
        c = float(np.mean(center[i:j]))
        wind[i:j] = bandpass(noise[i:j], c * 0.6, c * 1.6, soft=0.5)[: j - i]
    gust = 0.5 + 0.5 * np.clip(np.sin(2 * np.pi * 0.13 * t + 4.0), -0.6, 1.0)
    howl = sine(330, t) * (np.clip(gust - 0.8, 0, 1)) * 0.5
    return fade(norm(wind * gust + howl, 0.4), 0.8, 0.8)


def snd_ambience_wrongness(name):  # detuned drone, distinct from long_dark: sour cluster
    t = t_axis(6.0)
    d = (
        sine(87.31, t)
        + sine(92.5, t) * 0.9  # minor second rub
        + sine(174.6, t) * 0.4
        + sine(184.99, t) * 0.35
    )
    wob = 0.7 + 0.3 * sine(0.9, t) * sine(0.37, t)
    return fade(norm(d * wob, 0.4), 1.0, 1.0)


def snd_ambience_ward(name):  # faint protective shimmer
    rng = rng_for(name)
    t = t_axis(6.0)
    out = np.zeros_like(t)
    for f in (1567.98, 1975.53, 2349.32):
        out += sine(f, t, rng.uniform(0, 6)) * (0.5 + 0.5 * sine(rng.uniform(0.3, 0.8), t))
    hush = bandpass(rng.standard_normal(len(t)), 2000, 6000) * 0.08
    return fade(norm(out * 0.25 + hush, 0.22), 1.0, 1.0)


def snd_ui_click(name):
    t = t_axis(0.3)
    tick = sine(1100, t) * decay_env(t, 0.012)
    th = bandpass(rng_for(name).standard_normal(len(t)), 2000, 6000) * decay_env(t, 0.004)
    return norm(tick + 0.6 * th, 0.5)


def snd_ui_back(name):
    t = t_axis(0.3)
    tick = sine(700, t) * decay_env(t, 0.015)
    th = bandpass(rng_for(name).standard_normal(len(t)), 1200, 4000) * decay_env(t, 0.005)
    return norm(tick + 0.5 * th, 0.45)


def snd_ui_save(name):
    t = t_axis(0.5)
    n = len(t)
    a = sine(660, t) * decay_env(t, 0.05)
    i = int(0.12 * SR)
    b = np.zeros(n)
    b[i:] = sine(990, t[: n - i]) * decay_env(t[: n - i], 0.08)
    return norm(a + b, 0.5)


def snd_ui_refused(name):
    t = t_axis(0.4)
    n = len(t)
    buzz = np.sign(sine(140, t)) * 0.5 + sine(147, t) * 0.5  # flat dissonant burr
    env = decay_env(t, 0.05)
    i = int(0.15 * SR)
    env[i:] += decay_env(t[: n - i], 0.05)  # double refusal
    return norm(bandpass(buzz * np.clip(env, 0, 1), 90, 900), 0.5)


SPECS = {
    "phenomenon_still_air": snd_still_air,
    "phenomenon_long_dark": snd_long_dark,
    "phenomenon_ground_remembers": snd_ground_remembers,
    "phenomenon_standing_stones": snd_standing_stones,
    "phenomenon_the_swallowing": snd_the_swallowing,
    "phenomenon_the_quickening": snd_the_quickening,
    "phenomenon_the_blight": snd_the_blight,
    "phenomenon_wrongness_blood": snd_wrongness_blood,
    "phenomenon_shared_dream": snd_shared_dream,
    "phenomenon_day_twice": snd_day_twice,
    "consequence_unease": snd_consequence_unease,
    "consequence_flood": snd_consequence_flood,
    "consequence_dam_flood": snd_consequence_dam_flood,
    "consequence_famine": snd_consequence_famine,
    "consequence_migration": snd_consequence_migration,
    "consequence_quake": snd_consequence_quake,
    "consequence_cursed_place": snd_consequence_cursed_place,
    "consequence_soil_exhaustion": snd_consequence_soil_exhaustion,
    "consequence_scapegoat_schism": snd_consequence_scapegoat_schism,
    "consequence_medicine": snd_consequence_medicine,
    "consequence_predator_follows": snd_consequence_predator_follows,
    "consequence_hunt_heroism": snd_consequence_hunt_heroism,
    "consequence_rite_crystallizes": snd_consequence_rite_crystallizes,
    "consequence_schism_seed": snd_consequence_schism_seed,
    "consequence_mass_conversion": snd_consequence_mass_conversion,
    "consequence_heresy_schism": snd_consequence_heresy_schism,
    "event_born": snd_event_born,
    "event_died": snd_event_died,
    "event_stage_changed": snd_event_stage_changed,
    "event_knowledge_lost": snd_event_knowledge_lost,
    "event_belief_formed": snd_event_belief_formed,
    "event_main_settlement_changed": snd_event_main_settlement_changed,
    "event_world_ended": snd_event_world_ended,
    "event_settlement_founded": snd_event_settlement_founded,
    "event_discovery": snd_event_discovery,
    "event_fracture": snd_event_fracture,
    "event_war": snd_event_war,
    "event_schism": snd_event_schism,
    "ambience_season_0": snd_ambience_season_0,
    "ambience_season_1": snd_ambience_season_1,
    "ambience_season_2": snd_ambience_season_2,
    "ambience_season_3": snd_ambience_season_3,
    "ambience_wrongness": snd_ambience_wrongness,
    "ambience_ward": snd_ambience_ward,
    "ui_click": snd_ui_click,
    "ui_back": snd_ui_back,
    "ui_save": snd_ui_save,
    "ui_refused": snd_ui_refused,
}


def write_wav(path: str, x: np.ndarray) -> None:
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    for name, builder in sorted(SPECS.items()):
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, builder(name))
        print(f"wrote {name}.wav ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    main()
