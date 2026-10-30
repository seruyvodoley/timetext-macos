#!/usr/bin/env python3
"""Offline long-form Russian ASR adapter for SberDevices GigaAM-v3."""

from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
import wave
from pathlib import Path


def fmt_time(seconds: float) -> str:
    milliseconds = max(0, round(seconds * 1000))
    hours, rem = divmod(milliseconds, 3_600_000)
    minutes, rem = divmod(rem, 60_000)
    whole_seconds, milliseconds = divmod(rem, 1000)
    return f"{hours:02}:{minutes:02}:{whole_seconds:02},{milliseconds:03}"


def model_cache(resources: Path) -> Path:
    cache = Path.home() / "Library/Application Support/TimeText/GigaAM"
    cache.mkdir(parents=True, exist_ok=True)
    for name in ("v3_e2e_rnnt.ckpt", "v3_e2e_rnnt_tokenizer.model"):
        bundled = resources / name
        target = cache / name
        if not target.exists():
            if not bundled.is_file():
                raise FileNotFoundError(f"Не найдена модель GigaAM: {bundled}")
            target.symlink_to(bundled)
    return cache


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--model-dir", required=True)
    args = parser.parse_args()

    runtime_bin = Path(sys.executable).resolve().parent.parent / "bin"
    os.environ["PATH"] = str(runtime_bin) + os.pathsep + os.environ.get("PATH", "")

    import torch
    import gigaam

    torch.set_num_threads(max(2, min(8, os.cpu_count() or 4)))
    cache = model_cache(Path(args.model_dir))
    # CPU execution is the portable path for this bundled build and avoids
    # device-specific failures across Apple Silicon generations.
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = gigaam.load_model("v3_e2e_rnnt", device=device, download_root=str(cache))

    chunk_seconds = 24
    stride_seconds = 22
    all_words: list[tuple[float, float, str]] = []
    with wave.open(args.input, "rb") as source, tempfile.TemporaryDirectory(prefix="timetext-gigaam-") as temp:
        sample_rate = source.getframerate()
        if source.getnchannels() != 1 or sample_rate != 16000 or source.getsampwidth() != 2:
            raise ValueError("Ожидался монофонический WAV 16 кГц")
        total_frames = source.getnframes()
        total_duration = total_frames / sample_rate
        chunk_frames = chunk_seconds * sample_rate
        stride_frames = stride_seconds * sample_rate
        starts = list(range(0, total_frames, stride_frames))
        for index, start in enumerate(starts):
            frame_count = min(chunk_frames, total_frames - start)
            if frame_count <= 0:
                continue
            source.setpos(start)
            data = source.readframes(frame_count)
            chunk_path = Path(temp) / f"chunk-{index:05}.wav"
            with wave.open(str(chunk_path), "wb") as chunk:
                chunk.setnchannels(1)
                chunk.setsampwidth(2)
                chunk.setframerate(sample_rate)
                chunk.writeframes(data)

            try:
                result = model.transcribe(str(chunk_path), word_timestamps=True)
            except (RuntimeError, NotImplementedError):
                if device != "mps":
                    raise
                # Some PyTorch/macOS combinations lack an MPS kernel for a
                # particular operation. Retry on CPU rather than failing the job.
                model = gigaam.load_model(
                    "v3_e2e_rnnt", device="cpu", download_root=str(cache)
                )
                device = "cpu"
                result = model.transcribe(str(chunk_path), word_timestamps=True)
            chunk_duration = frame_count / sample_rate
            left_guard = 1.0 if index else 0.0
            right_guard = 1.0 if start + frame_count < total_frames else 0.0
            for word in result.words or []:
                center = (float(word.start) + float(word.end)) / 2
                if center < left_guard or center >= chunk_duration - right_guard:
                    continue
                text = str(word.text).strip()
                if not text:
                    continue
                all_words.append((start / sample_rate + float(word.start),
                                  start / sample_rate + float(word.end), text))

    all_words.sort(key=lambda item: item[0])
    captions: list[tuple[float, float, str]] = []
    pending: list[tuple[float, float, str]] = []

    def flush() -> None:
        if not pending:
            return
        text = " ".join(item[2] for item in pending)
        text = re.sub(r"\s+([,.;:!?])", r"\1", text)
        captions.append((pending[0][0], pending[-1][1], text))
        pending.clear()

    for word in all_words:
        if pending and (word[0] - pending[-1][1] > 1.0 or len(pending) >= 12 or
                        word[0] - pending[0][0] >= 9.0):
            flush()
        pending.append(word)
        if word[2].endswith((".", "!", "?")):
            flush()
    flush()

    if not captions and total_duration > 0:
        raise RuntimeError("GigaAM не распознала речь в аудиофайле")
    srt = "\n\n".join(
        f"{index}\n{fmt_time(start)} --> {fmt_time(max(end, start + 0.05))}\n{text}"
        for index, (start, end, text) in enumerate(captions, 1)
    )
    Path(args.output).write_text(srt + ("\n" if srt else ""), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
