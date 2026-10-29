"""Render the project's own vector artwork into Android/Flutter assets.

Run from any directory with Python and Pillow. No network or external artwork.
The paths below are the shared source for SVG, Android vector XML and PNGs.
"""

from pathlib import Path
import re

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets' / 'branding'
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
GREEN = '#2D5A43'
MINT = '#D8EDE2'
CREAM = '#F6FBF5'
ENVELOPE = 'M31 43 H77 Q81 43 81 47 V72 Q81 76 77 76 H31 Q27 76 27 72 V47 Q27 43 31 43 Z'
FOLD = 'M29 48 L54 64 L79 48'
LEAF = 'M50 50 C44 36 58 27 75 28 C75 43 66 53 50 50 Z'
VEIN = 'M50 50 Q59 40 69 34'
SHAPES = [(ENVELOPE, GREEN, None, 0), (FOLD, None, CREAM, 3.2),
          (LEAF, GREEN, MINT, 2), (VEIN, None, CREAM, 2.4)]


def curve_points(command, origin, values):
    result = []
    for step in range(1, 33):
        t = step / 32
        u = 1 - t
        if command == 'Q':
            point = tuple(u*u*origin[d] + 2*u*t*values[d] + t*t*values[d+2] for d in (0, 1))
        else:
            point = tuple(u**3*origin[d] + 3*u*u*t*values[d] + 3*u*t*t*values[d+2] + t**3*values[d+4] for d in (0, 1))
        result.append(point)
    return result


def points(path):
    tokens = re.findall(r'[A-Z]|-?\d+(?:\.\d+)?', path)
    result, current, start = [], (0, 0), (0, 0)
    index = 0
    while index < len(tokens):
        command = tokens[index]
        index += 1
        count = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'Q': 4, 'C': 6, 'Z': 0}[command]
        values = list(map(float, tokens[index:index + count]))
        index += count
        if command in ('M', 'L'):
            current = tuple(values)
            if command == 'M':
                start = current
            result.append(current)
        elif command in ('H', 'V'):
            current = (values[0], current[1]) if command == 'H' else (current[0], values[0])
            result.append(current)
        elif command in ('Q', 'C'):
            result.extend(curve_points(command, current, values))
            current = result[-1]
        else:
            result.append(start)
            current = start
    return result


def render(size, background=None):
    scale = size * 4 / 108
    image = Image.new('RGBA', (size * 4, size * 4), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for path, fill, stroke, width in SHAPES:
        contour = [(x * scale, y * scale) for x, y in points(path)]
        if fill:
            draw.polygon(contour, fill=fill)
        if stroke:
            radius = width * scale / 2
            draw.line(contour, fill=stroke, width=round(width * scale), joint='curve')
            for x, y in (contour[0], contour[-1]):
                draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=stroke)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8')


def write_launcher_pngs():
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        folder = RES / f'mipmap-{density}'
        folder.mkdir(parents=True, exist_ok=True)
        icon = render(size, MINT)
        icon.save(folder / 'ic_launcher.png')
        mask = Image.new('L', (size * 4, size * 4))
        ImageDraw.Draw(mask).ellipse((0, 0, size*4, size*4), fill=255)
        icon.putalpha(mask.resize((size, size), Image.Resampling.LANCZOS))
        icon.save(folder / 'ic_launcher_round.png')


def write_adaptive_icons():
    for version in (26, 33):
        adaptive = '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
        if version == 33:
            adaptive += '    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
        adaptive += '</adaptive-icon>\n'
        for name in ('ic_launcher', 'ic_launcher_round'):
            write(RES / f'mipmap-anydpi-v{version}' / f'{name}.xml', adaptive)


def write_preview():
    preview = Image.new('RGB', (960, 320), CREAM)
    draw = ImageDraw.Draw(preview)
    for index, shape in enumerate(('square', 'round', 'squircle')):
        icon = render(240, MINT)
        mask = Image.new('L', (240, 240))
        mask_draw = ImageDraw.Draw(mask)
        if shape == 'round':
            mask_draw.ellipse((0, 0, 239, 239), fill=255)
        else:
            mask_draw.rounded_rectangle((0, 0, 239, 239), radius=54 if shape == 'squircle' else 0, fill=255)
        preview.paste(icon, (40+index*320, 32), mask)
        draw.text((40+index*320, 290), shape, fill=GREEN)
    preview.save(ASSETS / 'android_icon_preview.png')


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    paths = '\n'.join(
        f'  <path d="{path}" fill="{fill or "none"}" stroke="{stroke or "none"}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'
        for path, fill, stroke, width in SHAPES
    )
    write(ASSETS / 'kakeibo_zen.svg',
          f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="1024" height="1024">\n'
          f'  <title>Kakeibo Zen — phong bao và lá</title>\n  <path fill="{MINT}" d="M0 0 H108 V108 H0 Z"/>\n{paths}\n</svg>\n')
    render(1024, MINT).save(ASSETS / 'kakeibo_zen_1024.png')
    render(1080).crop((220, 220, 860, 860)).resize((512, 512), Image.Resampling.LANCZOS).save(ASSETS / 'kakeibo_mark.png')
    write_launcher_pngs()
    vector_paths = '\n'.join(
        f'    <path android:pathData="{path}" android:fillColor="{fill or "#00000000"}"'
        + (f' android:strokeColor="{stroke}" android:strokeWidth="{width}" android:strokeLineCap="round" android:strokeLineJoin="round"' if stroke else '') + '/>'
        for path, fill, stroke, width in SHAPES
    )
    vector_header = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n'
    write(RES / 'drawable' / 'ic_launcher_foreground.xml', vector_header + vector_paths + '\n</vector>\n')
    # Even-odd contours cut out folds/veins so all visible pixels have one alpha mask.
    mono = ENVELOPE + ' M30 48 L54 63 L78 48 L78 52 L54 67 L30 52 Z ' + LEAF + ' M52 47 Q60 38 69 33 L70 35 Q61 41 54 49 Z'
    write(RES / 'drawable' / 'ic_launcher_monochrome.xml', vector_header + f'    <path android:fillColor="#FF000000" android:fillType="evenOdd" android:pathData="{mono}"/>\n</vector>\n')
    write(RES / 'values' / 'launcher_colors.xml', f'<resources>\n    <color name="ic_launcher_background">{MINT}</color>\n</resources>\n')
    write_adaptive_icons()
    write_preview()


if __name__ == '__main__':
    main()
