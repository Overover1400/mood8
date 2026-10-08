"""Generate the iOS AppIcon set from assets/icon/mood8_logo.png.

Three things this handles that a naive resize does not:

1. ALPHA IS REMOVED. mood8_logo.png is genuinely transparent at the corners
   and Apple rejects any App Store icon carrying an alpha channel - not at
   build time, but during processing, by email. Every slot is flattened onto
   the brand background and written as RGB with no alpha channel at all.

2. NO ROUNDED CORNERS ARE APPLIED. iOS masks icons itself; pre-rounding shows
   up as visibly double-rounded on device.

3. THE MARK IS CENTRED. The source art sits off-centre - 140px of padding on
   the left against 81px on the right - which is invisible in a 1024px
   artboard and obvious at 40px on a home screen. The ink bounding box is
   measured and recentred before scaling.

Background #0A0612 is not a choice made here: it is already the Android
adaptive-icon background (android/app/src/main/res/values/colors.xml) and the
web manifest background_color. Keeping all three identical is the point.

Run from the repo root:  python3 brand/build_ios_icons.py
"""
import json
import os

from PIL import Image

SOURCE = 'assets/icon/mood8_logo.png'
APPICON = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
BACKGROUND = (0x0A, 0x06, 0x12)


def master() -> Image.Image:
    """A 1024px opaque square with the mark optically centred."""
    art = Image.open(SOURCE).convert('RGBA')
    w, h = art.size

    box = art.getchannel('A').getbbox()
    if box is None:
        raise SystemExit(f'{SOURCE} is entirely transparent')

    # Recentre by the ink, not the canvas.
    dx = (w - (box[2] - box[0])) // 2 - box[0]
    dy = (h - (box[3] - box[1])) // 2 - box[1]
    centred = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    centred.paste(art, (dx, dy), art)

    # Flatten. convert('RGB') after the paste guarantees no alpha channel
    # survives into the PNG, which is the part Apple actually checks.
    flat = Image.new('RGB', (w, h), BACKGROUND)
    flat.paste(centred, (0, 0), centred)
    print(f'source {w}x{h}, ink recentred by ({dx:+d}, {dy:+d}), '
          f'flattened onto #{BACKGROUND[0]:02X}{BACKGROUND[1]:02X}'
          f'{BACKGROUND[2]:02X}')
    return flat


def main() -> None:
    base = master()
    contents = json.load(open(f'{APPICON}/Contents.json'))

    # Several slots share a filename (iPhone and iPad both use
    # Icon-App-20x20@2x.png, for instance), so collapse to unique
    # filename -> pixel size before writing.
    wanted: dict[str, int] = {}
    for entry in contents['images']:
        px = round(float(entry['size'].split('x')[0])
                   * int(entry['scale'].rstrip('x')))
        name = entry['filename']
        if name in wanted and wanted[name] != px:
            raise SystemExit(f'{name} wanted at two sizes: '
                             f'{wanted[name]} and {px}')
        wanted[name] = px

    for name, px in sorted(wanted.items(), key=lambda kv: kv[1]):
        out = base.resize((px, px), Image.LANCZOS)
        path = os.path.join(APPICON, name)
        out.save(path, 'PNG')
        assert out.mode == 'RGB', f'{name} kept an alpha channel'
        print(f'  {px:4}px  {name}')

    print(f'\n{len(wanted)} icons written to {APPICON}')


if __name__ == '__main__':
    main()
