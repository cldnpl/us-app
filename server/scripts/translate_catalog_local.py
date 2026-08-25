#!/usr/bin/env python3
r"""Translate the game catalog locally with NLLB, never a hosted LLM API.

Input is the JSON emitted by cmd/dump-catalog. Output is a tab-delimited CSV
that can be loaded into content_translations with psql's \copy command.
"""

import argparse
import csv
import gc
import json
import re
import sys
from pathlib import Path

import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer


MODEL_NAME = "facebook/nllb-200-distilled-600M"
LANGUAGES = {
    "ar": "arb_Arab",
    "bn": "ben_Beng",
    "da": "dan_Latn",
    "de": "deu_Latn",
    "es": "spa_Latn",
    "fa": "pes_Arab",
    "fil": "tgl_Latn",
    "fr": "fra_Latn",
    "hi": "hin_Deva",
    "id": "ind_Latn",
    "it": "ita_Latn",
    "ja": "jpn_Jpan",
    "ko": "kor_Hang",
    "nl": "nld_Latn",
    "pl": "pol_Latn",
    "pt-BR": "por_Latn",
    "ru": "rus_Cyrl",
    "sw": "swh_Latn",
    "th": "tha_Thai",
    "tr": "tur_Latn",
    "uk": "ukr_Cyrl",
    "ur": "urd_Arab",
    "uz": "uzn_Latn",
    "vi": "vie_Latn",
    "zh-Hans": "zho_Hans",
}

# Keep emoji attached to an option even if the translation model drops one.
EMOJI_RE = re.compile(
    "[\\U0001F000-\\U0001FAFF\\u2600-\\u27BF\\uFE0F]"
)


def emojis(text):
    return EMOJI_RE.findall(text)


def preserve_emojis(source, translated):
    # A seq2seq model can occasionally emit an empty string. Content values
    # are NOT NULL in Postgres, so keep the English source as a safe fallback.
    translated = translated.strip()
    if not translated:
        return source
    missing = [emoji for emoji in emojis(source) if emoji not in translated]
    if missing:
        return translated.rstrip() + " " + "".join(missing)
    return translated


def is_complete_translation(path, item_count):
    if not path.exists():
        return False
    with path.open("r", encoding="utf-8", newline="") as existing:
        reader = csv.reader(existing, delimiter="\t")
        rows = list(reader)
    return (
        len(rows) == item_count + 1
        and bool(rows)
        and all(len(row) >= 5 and row[4].strip() for row in rows[1:])
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--langs", default=",".join(LANGUAGES))
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--chunk-size", type=int, default=320)
    parser.add_argument("--max-length", type=int, default=256)
    args = parser.parse_args()

    if (args.output is None) == (args.output_dir is None):
        raise SystemExit("provide exactly one of --output or --output-dir")

    items = json.loads(args.input.read_text())
    requested = [lang.strip() for lang in args.langs.split(",") if lang.strip()]
    unknown = sorted(set(requested) - set(LANGUAGES))
    if unknown:
        raise SystemExit(f"unsupported languages: {', '.join(unknown)}")

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"loading tokenizer for {MODEL_NAME} on {device}", file=sys.stderr, flush=True)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, local_files_only=True)

    if args.output_dir is not None:
        args.output_dir.mkdir(parents=True, exist_ok=True)
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)

    combined = args.output.open("w", encoding="utf-8", newline="") if args.output else None
    try:
        for lang in requested:
            target = LANGUAGES[lang]
            output = args.output_dir / f"{lang}.tsv" if args.output_dir else None
            if output is not None and output.exists():
                if is_complete_translation(output, len(items)):
                    print(f"skipping completed {lang}", file=sys.stderr, flush=True)
                    continue
                output.unlink()
            stream = output.open("w", encoding="utf-8", newline="") if output else combined
            writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
            writer.writerow(["content_type", "content_id", "field", "lang", "value"])
            print(f"translating {lang}: {len(items)} strings", file=sys.stderr, flush=True)
            for chunk_start in range(0, len(items), args.chunk_size):
                chunk_end = min(chunk_start + args.chunk_size, len(items))
                print(f"  loading model chunk {chunk_start}/{len(items)}", file=sys.stderr, flush=True)
                model = AutoModelForSeq2SeqLM.from_pretrained(MODEL_NAME, local_files_only=True).to(device)
                model.eval()
                for start in range(chunk_start, chunk_end, args.batch_size):
                    batch = items[start : min(start + args.batch_size, chunk_end)]
                    texts = [item["text"] for item in batch]
                    encoded = tokenizer(
                        texts,
                        return_tensors="pt",
                        padding=True,
                        truncation=True,
                        max_length=args.max_length,
                    )
                    encoded = {key: value.to(device) for key, value in encoded.items()}
                    with torch.inference_mode():
                        generated = model.generate(
                            **encoded,
                            forced_bos_token_id=tokenizer.convert_tokens_to_ids(target),
                            max_length=args.max_length,
                            # Greedy decoding is substantially faster on the
                            # local model and is sufficient for a checked-in
                            # catalog. There is no paid/provider fallback.
                            num_beams=1,
                        )
                    values = tokenizer.batch_decode(generated, skip_special_tokens=True)
                    for item, value in zip(batch, values):
                        value = preserve_emojis(item["text"], value.strip())
                        writer.writerow(
                            [
                                item["contentType"],
                                item["contentID"],
                                item["field"],
                                lang,
                                value,
                            ]
                        )
                    stream.flush()
                    if (start // args.batch_size + 1) % 10 == 0:
                        done = min(start + args.batch_size, len(items))
                        print(f"  {lang}: {done}/{len(items)}", file=sys.stderr, flush=True)
                del model
                del encoded, generated, values, batch
                gc.collect()
                if device == "mps":
                    torch.mps.empty_cache()
            stream.flush()
            if output:
                stream.close()
    finally:
        if combined:
            combined.close()


if __name__ == "__main__":
    main()
