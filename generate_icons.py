"""Generate OrderVista truck app icons at all required sizes.

Draws a delivery-truck silhouette using PIL geometric primitives
(rounded rectangles, ellipses) so no external font/glyph is needed.
"""
from PIL import Image, ImageDraw
import os

BG_COLOR = (0, 78, 124)       # #004E7C  brand primary
ICON_COLOR = (255, 255, 255)  # white
SIZES = {
    "icon_1024.png": 1024,
    "icon_512.png": 512,
    "icon_192.png": 192,
    "icon_48.png": 48,
    "icon_32.png": 32,
}
OUT_DIR = r"c:\Users\asus\Desktop\CS4514_FYP\fyp_mobile_app\web\icons"


def _draw_truck(draw, size):
    """Draw a stylised delivery-truck silhouette centred in *size* px."""
    # All coordinates are fractions of *size* so the icon scales cleanly.
    s = size

    # --- cargo box (left portion) ---
    # top-left to bottom-right, occupies left ~58% of the truck zone
    pad_x = s * 0.18          # horizontal padding from icon edge
    pad_top = s * 0.28        # top padding
    pad_bot = s * 0.62        # bottom of main body (above wheels)

    cargo_l = pad_x
    cargo_t = pad_top
    cargo_r = pad_x + s * 0.42
    cargo_b = pad_bot
    cr = s * 0.03             # small corner radius
    draw.rounded_rectangle(
        [(cargo_l, cargo_t), (cargo_r, cargo_b)],
        radius=int(cr), fill=ICON_COLOR,
    )

    # --- cab (right portion, shorter & narrower) ---
    cab_l = cargo_r - s * 0.01   # slight overlap
    cab_t = pad_top + s * 0.18   # cab roof is lower than cargo roof
    cab_r = s - pad_x
    cab_b = pad_bot
    draw.rounded_rectangle(
        [(cab_l, cab_t), (cab_r, cab_b)],
        radius=int(cr * 1.5), fill=ICON_COLOR,
    )

    # Windshield notch (darker inset in cab)
    ws_l = cab_l + s * 0.06
    ws_t = cab_t + s * 0.04
    ws_r = cab_r - s * 0.04
    ws_b = cab_t + s * 0.15
    draw.rounded_rectangle(
        [(ws_l, ws_t), (ws_r, ws_b)],
        radius=int(cr), fill=BG_COLOR,
    )

    # --- chassis bar (full underside strip) ---
    bar_t = pad_bot
    bar_b = pad_bot + s * 0.045
    draw.rectangle([(cargo_l, bar_t), (cab_r, bar_b)], fill=ICON_COLOR)

    # --- wheels ---
    wheel_r = s * 0.065       # wheel radius
    wheel_y = bar_b + wheel_r * 0.3   # centre-y sits just below bar

    # rear wheel
    w1_cx = cargo_l + s * 0.12
    draw.ellipse(
        [(w1_cx - wheel_r, wheel_y - wheel_r),
         (w1_cx + wheel_r, wheel_y + wheel_r)],
        fill=ICON_COLOR,
    )
    # inner hub
    hub = wheel_r * 0.45
    draw.ellipse(
        [(w1_cx - hub, wheel_y - hub),
         (w1_cx + hub, wheel_y + hub)],
        fill=BG_COLOR,
    )

    # front wheel
    w2_cx = cab_r - s * 0.10
    draw.ellipse(
        [(w2_cx - wheel_r, wheel_y - wheel_r),
         (w2_cx + wheel_r, wheel_y + wheel_r)],
        fill=ICON_COLOR,
    )
    draw.ellipse(
        [(w2_cx - hub, wheel_y - hub),
         (w2_cx + hub, wheel_y + hub)],
        fill=BG_COLOR,
    )

    # Axle gap — cut out strip between wheels so chassis doesn't cover them
    gap_t = bar_t
    gap_b = wheel_y + wheel_r
    # gap between rear and front wheel
    draw.rectangle(
        [(w1_cx + wheel_r + s*0.01, gap_t),
         (w2_cx - wheel_r - s*0.01, gap_b)],
        fill=BG_COLOR,
    )


def make_icon(size, path, corner_radius_frac=0.18):
    """Create a rounded-square icon with a truck silhouette."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background
    r = int(size * corner_radius_frac)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=r, fill=BG_COLOR)

    _draw_truck(draw, size)

    img.save(path, "PNG")
    print(f"  {os.path.basename(path)}  ({size}x{size})")

print("Generating OrderVista truck icons...")
for name, sz in SIZES.items():
    make_icon(sz, os.path.join(OUT_DIR, name))

# Also save copies for specific locations
import shutil

# favicon.png (32x32) -> web/favicon.png
shutil.copy2(
    os.path.join(OUT_DIR, "icon_32.png"),
    r"c:\Users\asus\Desktop\CS4514_FYP\fyp_mobile_app\web\favicon.png",
)
print("  web/favicon.png  (32x32)")

# Overwrite the old web/icons files
shutil.copy2(os.path.join(OUT_DIR, "icon_192.png"), os.path.join(OUT_DIR, "Icon-192.png"))
shutil.copy2(os.path.join(OUT_DIR, "icon_512.png"), os.path.join(OUT_DIR, "Icon-512.png"))
shutil.copy2(os.path.join(OUT_DIR, "icon_1024.png"), os.path.join(OUT_DIR, "app_launcher_icon.png"))
print("  Icon-192.png, Icon-512.png, app_launcher_icon.png overwritten")

# Also overwrite all the scattered favicon.png files in asset folders
favicon_locations = [
    r"assets\videos\favicon.png",
    r"assets\rive_animations\favicon.png",
    r"assets\audios\favicon.png",
    r"assets\images\favicon.png",
    r"assets\pdfs\favicon.png",
    r"assets\fonts\favicon.png",
    r"assets\jsons\favicon.png",
]
base = r"c:\Users\asus\Desktop\CS4514_FYP\fyp_mobile_app"
for rel in favicon_locations:
    dst = os.path.join(base, rel)
    if os.path.exists(dst):
        shutil.copy2(os.path.join(OUT_DIR, "icon_32.png"), dst)
        print(f"  {rel} replaced")

# Main launcher icon for flutter_launcher_icons (referenced in pubspec.yaml)
launcher_dst = os.path.join(base, "assets", "images", "app_launcher_icon.png")
shutil.copy2(os.path.join(OUT_DIR, "icon_1024.png"), launcher_dst)
print(f"  assets/images/app_launcher_icon.png  (1024x1024)")

# Clean up intermediate sizes
for name in ["icon_1024.png", "icon_512.png", "icon_192.png", "icon_48.png", "icon_32.png"]:
    p = os.path.join(OUT_DIR, name)
    if os.path.exists(p) and name not in ["icon_512.png", "icon_192.png"]:
        # Keep 512 and 192 as they are needed; remove temp extras
        pass  # Actually keep all, they don't hurt

print("\nDone! All icons updated to OrderVista truck logo.")
