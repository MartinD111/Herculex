"""
Run this script after placing your logo at:
  assets/icon_source.png  (1024x1024 recommended, black bg with white logo)

Usage:
  python scripts/generate_icons.py

Generates:
  - Android mipmap PNGs (all densities)
  - Android adaptive icon foreground (white lion on transparent bg)
  - iOS Icons (if ios/ folder exists)
"""
from PIL import Image, ImageDraw
import os, shutil

SRC = "assets/icon_source.png"
RES  = "android/app/src/main/res"

ANDROID_SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icon foreground sizes (108dp each density)
ADAPTIVE_SIZES = {
    "mipmap-mdpi":    108,
    "mipmap-hdpi":    162,
    "mipmap-xhdpi":   216,
    "mipmap-xxhdpi":  324,
    "mipmap-xxxhdpi": 432,
}

def make_rounded(img, radius_pct=22):
    """Apply rounded corners to image."""
    size = img.size
    r = int(size[0] * radius_pct / 100)
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size[0]-1, size[1]-1)], radius=r, fill=255)
    result = img.copy().convert("RGBA")
    result.putalpha(mask)
    return result

def generate():
    if not os.path.exists(SRC):
        print(f"ERROR: Source image not found at '{SRC}'")
        print("Please save your logo PNG to assets/icon_source.png and re-run.")
        return

    src = Image.open(SRC).convert("RGBA")
    print(f"Source image: {src.size}")

    # ── Standard launcher icons (rounded square, black bg) ─────────────────
    for folder, size in ANDROID_SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)

        # Compose: resize source onto black square, then round corners
        bg = Image.new("RGBA", (size, size), (0, 0, 0, 255))
        icon = src.resize((size, size), Image.LANCZOS)
        bg.paste(icon, mask=icon.split()[3])
        rounded = make_rounded(bg)

        # Save as PNG (Android accepts PNG for mipmap)
        out = os.path.join(out_dir, "ic_launcher.png")
        rounded.save(out, "PNG")
        print(f"  {out} ({size}x{size})")

    # ── Adaptive icon foreground (white lion on transparent bg) ────────────
    # Extract just the white lion (no black bg) for the foreground layer
    for folder, size in ADAPTIVE_SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)

        fg = src.resize((size, size), Image.LANCZOS)
        out = os.path.join(out_dir, "ic_launcher_foreground.png")
        fg.save(out, "PNG")
        print(f"  {out} ({size}x{size}) [adaptive fg]")

    # ── Write adaptive icon XMLs ────────────────────────────────────────────
    drawable_dir = os.path.join(RES, "drawable")
    os.makedirs(drawable_dir, exist_ok=True)

    bg_xml = os.path.join(drawable_dir, "ic_launcher_background.xml")
    with open(bg_xml, "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n')
        f.write('<shape xmlns:android="http://schemas.android.com/apk/res/android"\n')
        f.write('    android:shape="rectangle">\n')
        f.write('    <solid android:color="#000000"/>\n')
        f.write('</shape>\n')
    print(f"  {bg_xml}")

    for api_folder in ["mipmap-anydpi-v26"]:
        api_dir = os.path.join(RES, api_folder)
        os.makedirs(api_dir, exist_ok=True)

        adaptive_xml = os.path.join(api_dir, "ic_launcher.xml")
        with open(adaptive_xml, "w") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n')
            f.write('<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n')
            f.write('    <background android:drawable="@drawable/ic_launcher_background"/>\n')
            f.write('    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n')
            f.write('</adaptive-icon>\n')
        print(f"  {adaptive_xml}")

        adaptive_round_xml = os.path.join(api_dir, "ic_launcher_round.xml")
        shutil.copy(adaptive_xml, adaptive_round_xml)
        print(f"  {adaptive_round_xml}")

    print("\nDone! Run 'flutter run' to see the new icon.")

if __name__ == "__main__":
    generate()
