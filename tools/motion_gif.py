"""Animated GIF of the frames recorded by the "motion" mode of tests/screenshot.gd (motion_NNN.png), to judge how
smooth the Pokémon move. Several folders (versions of the view, same seed) are put side by side, each with its label.

  python -I tools/motion_gif.py out.gif "build/shots/motion_before=Trước" "build/shots/motion_after=Sau" [--fps 50]
      [--crop x,y,w,h] [--scale 0.5] [--start 0] [--count 220] [--strip strip.png --strip-step 2 --strip-count 12]

--fps must be the --fixed-fps the frames were recorded with (SHOT_ENGINE_ARGS), so the GIF plays in real time.
--strip also writes a still of consecutive frames (one row per folder) to look at without playing the GIF.
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "fonts", "BeVietnamPro-Bold.ttf")


def load_frames(folder, start, count):
    names = sorted(n for n in os.listdir(folder) if n.startswith("motion_") and n[7:10].isdigit() and n.endswith(".png"))
    return [os.path.join(folder, n) for n in names[start:start + count]]


def tile(path, crop, scale):
    img = Image.open(path).convert("RGB")
    if crop:
        img = img.crop((crop[0], crop[1], crop[0] + crop[2], crop[1] + crop[3]))
    if scale != 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("folders", nargs="+", help="folder[=label]")
    ap.add_argument("--fps", type=float, default=50.0)
    ap.add_argument("--crop", default="", help="x,y,w,h of every frame")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--count", type=int, default=100000)
    ap.add_argument("--strip", default="")
    ap.add_argument("--strip-step", type=int, default=2)
    ap.add_argument("--strip-count", type=int, default=12)
    args = ap.parse_args()

    columns = []
    for spec in args.folders:
        folder, _, label = spec.partition("=")
        columns.append((load_frames(folder, args.start, args.count), label or os.path.basename(folder)))
    n = min(len(c[0]) for c in columns)
    if n == 0:
        raise SystemExit("no motion_NNN.png frames")
    crop = tuple(int(v) for v in args.crop.split(",")) if args.crop else None
    font = ImageFont.truetype(FONT, 18) if os.path.exists(FONT) else ImageFont.load_default()
    label_h = 32
    sheets = []
    for i in range(n):
        tiles = [(tile(paths[i], crop, args.scale), label) for paths, label in columns]
        w = sum(t[0].width for t in tiles) + 6 * (len(tiles) - 1)
        h = max(t[0].height for t in tiles) + label_h
        sheet = Image.new("RGB", (w, h), (12, 14, 18))
        draw = ImageDraw.Draw(sheet)
        x = 0
        for img, label in tiles:
            sheet.paste(img, (x, label_h))
            draw.text((x + 10, 5), label, fill=(240, 240, 240), font=font)
            x += img.width + 6
        sheets.append(sheet)
    # one palette for every frame (from a few frames side by side): the GIF then only stores what changed
    picks = sheets[:: max(1, n // 6)][:6]
    sample = Image.new("RGB", (picks[0].width, picks[0].height * len(picks)))
    for k, s in enumerate(picks):
        sample.paste(s, (0, k * s.height))
    palette = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    frames = [s.quantize(palette=palette, dither=Image.Dither.NONE) for s in sheets]
    duration = round(1000.0 / args.fps)
    frames[0].save(args.out, save_all=True, append_images=frames[1:], duration=duration, loop=0, optimize=True)
    print("%s: %d frames, %dx%d, %d ms each, %.1f MB" % (args.out, n, frames[0].width, frames[0].height, duration,
                                                         os.path.getsize(args.out) / 1e6))
    if args.strip:
        rows = []
        for paths, label in columns:
            pics = [tile(paths[i], crop, args.scale) for i in range(0, n, args.strip_step)][: args.strip_count]
            row = Image.new("RGB", (sum(p.width for p in pics) + 2 * (len(pics) - 1), pics[0].height + label_h), (12, 14, 18))
            ImageDraw.Draw(row).text((8, 5), label, fill=(240, 240, 240), font=font)
            x = 0
            for p in pics:
                row.paste(p, (x, label_h))
                x += p.width + 2
            rows.append(row)
        strip = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows)), (12, 14, 18))
        y = 0
        for r in rows:
            strip.paste(r, (0, y))
            y += r.height
        strip.save(args.strip)
        print("strip:", args.strip, strip.size)


if __name__ == "__main__":
    main()
