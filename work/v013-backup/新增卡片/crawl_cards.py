#!/usr/bin/env python3
"""Download every Project Multicolor card as a genuinely encoded JPEG.

pip install Pillow
python crawl_cards.py
Images and reports are saved beside this script by default.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
from datetime import datetime, timezone
from io import BytesIO
import json
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urljoin, urlsplit
from urllib.request import Request, urlopen

try:
    from PIL import Image, ImageOps
except ImportError:
    raise SystemExit('Please install Pillow: python -m pip install Pillow')

BASE = 'https://project-multicolor.com'
INDEX = BASE + '/data/cards.json'
HEADERS = {'User-Agent': 'Mozilla/5.0', 'Referer': BASE + '/zh/cards/'}


def fetch(url):
    for attempt in range(4):
        try:
            with urlopen(Request(url, headers=HEADERS), timeout=45) as response:
                return response.read()
        except HTTPError as exc:
            if exc.code not in (408, 429, 500, 502, 503, 504):
                raise
            if attempt == 3:
                raise
            delay = min(60, int(exc.headers.get('Retry-After', '0')) if
                        exc.headers.get('Retry-After', '').isdigit() else 0)
            time.sleep(max(delay, 2 ** attempt))
        except (OSError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)


def card_title(card):
    # Same rule as the site's card-list heading: only character cards show title.
    name = str(card.get('name') or card['id']).strip()
    title = str(card.get('title') or '').strip()
    return f'{title}「{name}」' if card.get('card_type') == 'character' and title else name


def safe_name(name):
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '_', name).strip().rstrip('. ')
    name = name[:100].rstrip('. ') or 'unnamed'
    if re.match(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)', name, re.I):
        name = '_' + name
    return name


def filenames(cards):
    names = [safe_name(card_title(c)) for c in cards]
    counts = Counter(n.casefold() for n in names)
    used = set()
    result = {}
    for card, name in zip(cards, names):
        stem = name if counts[name.casefold()] == 1 else f'{name}__{safe_name(card["id"])}'
        candidate = stem + '.jpg'
        number = 2
        while candidate.casefold() in used:
            candidate = f'{stem}__{number}.jpg'
            number += 1
        used.add(candidate.casefold())
        result[card['id']] = candidate
    return result


def sources(card, prefer_original):
    urls = card.get('image_urls') or {}
    raw = ([urls.get('original')] if prefer_original else []) + [urls.get('x1'), card.get('image_url'), urls.get('original')]
    result = []
    for path in raw:
        if not path:
            continue
        url = urljoin(BASE, path)
        if urlsplit(url).scheme not in ('http', 'https'):
            continue
        if url not in result:
            result.append(url)
    return result


def jpeg_info(path):
    with Image.open(path) as im:
        if im.format != 'JPEG':
            raise ValueError('Existing file is not JPEG')
        im.load()
        return im.size


def download(card, filename, out, previous, prefer_original):
    row = {'id': card['id'], 'name': card_title(card), 'file': filename,
           'version': card.get('version'), 'status': 'failed', 'url': '', 'error': ''}
    target = out / filename
    urls = sources(card, prefer_original)
    old = previous.get(card['id'], {})
    if target.exists():
        if old.get('file') != filename or old.get('status') not in ('ok', 'skipped'):
            row['error'] = 'Untracked file already exists; not overwritten'
            return row
        if old.get('version') == card.get('version') and old.get('url') in urls:
            try:
                width, height = jpeg_info(target)
                row.update(status='skipped', url=old['url'], width=width, height=height)
                return row
            except (OSError, ValueError):
                pass
    errors = []
    for url in urls:
        temporary = target.with_suffix('.jpg.part')
        try:
            data = fetch(url)
            with Image.open(BytesIO(data)) as source:
                source.load()
                im = ImageOps.exif_transpose(source).convert('RGBA')
                background = Image.new('RGB', im.size, 'white')
                background.paste(im, mask=im.getchannel('A'))
                background.save(temporary, format='JPEG', quality=95, subsampling=0, optimize=True)
            width, height = jpeg_info(temporary)
            temporary.replace(target)
            row.update(status='ok', url=url, width=width, height=height)
            return row
        except Exception as exc:
            errors.append(f'{url}: {type(exc).__name__}: {exc}')
            temporary.unlink(missing_ok=True)
    row['error'] = '; '.join(errors) or 'No image URL in card index'
    return row


def save_manifest(path, records):
    temp = path.with_suffix('.json.tmp')
    temp.write_text(json.dumps({'updated_at': datetime.now(timezone.utc).isoformat(),
                               'source': INDEX, 'cards': records}, ensure_ascii=False, indent=2), encoding='utf-8')
    temp.replace(path)


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--workers', type=int, default=6)
    parser.add_argument('--prefer-original', action='store_true', help='Try original image before displayed image; some original URLs return 404')
    parser.add_argument('--limit', type=int, default=0, help='Optional small test run; zero means all cards')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    data = fetch(INDEX)
    cards = json.loads(data)
    if not isinstance(cards, list) or not cards or not all(isinstance(c, dict) and c.get('id') for c in cards):
        raise ValueError('Unexpected card-index schema')
    if len({c['id'] for c in cards}) != len(cards):
        raise ValueError('Duplicate card IDs in source index')
    (out / 'cards_index.json').write_bytes(data)
    names = filenames(cards)
    if args.limit > 0:
        cards = cards[:args.limit]
    manifest = out / 'download_manifest.json'
    records = json.loads(manifest.read_text(encoding='utf-8'))['cards'] if manifest.exists() else {}
    print(f'Cards: {len(cards)} | Output: {out}', flush=True)
    counts = Counter()
    with ThreadPoolExecutor(max_workers=max(1, min(8, args.workers))) as pool:
        futures = [pool.submit(download, c, names[c['id']], out, records.copy(), args.prefer_original) for c in cards]
        for number, future in enumerate(as_completed(futures), 1):
            row = future.result()
            records[row['id']] = row
            counts[row['status']] += 1
            save_manifest(manifest, records)
            print(f'[{number}/{len(cards)}] {row["status"]}: {row["file"]}', flush=True)
    fields = ['id', 'name', 'file', 'status', 'width', 'height', 'url', 'version', 'error']
    with (out / 'download_report.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(records[c['id']] for c in cards)
    print(f'Done: downloaded={counts["ok"]}, skipped={counts["skipped"]}, failed={counts["failed"]}', flush=True)
    return 1 if counts['failed'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
