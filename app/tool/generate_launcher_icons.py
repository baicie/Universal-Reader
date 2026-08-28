from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
src = Image.open(root / "assets/branding/app_icon.png").convert("RGBA")


def save_png(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    src.resize((size, size), Image.Resampling.LANCZOS).save(path, "PNG")
    print(f"wrote {path} {size}x{size}")


def main() -> None:
    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android.items():
        save_png(
            root / "android/app/src/main/res" / folder / "ic_launcher.png",
            size,
        )

    save_png(root / "web/favicon.png", 32)
    save_png(root / "web/icons/Icon-192.png", 192)
    save_png(root / "web/icons/Icon-512.png", 512)
    save_png(root / "web/icons/Icon-maskable-192.png", 192)
    save_png(root / "web/icons/Icon-maskable-512.png", 512)

    macos_dir = root / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }.items():
        save_png(macos_dir / name, size)

    ios_dir = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if ios_dir.exists():
        save_png(ios_dir / "Icon-App-1024x1024@1x.png", 1024)
        for size, scale, filename in [
            (20, 1, "Icon-App-20x20@1x.png"),
            (20, 2, "Icon-App-20x20@2x.png"),
            (20, 3, "Icon-App-20x20@3x.png"),
            (29, 1, "Icon-App-29x29@1x.png"),
            (29, 2, "Icon-App-29x29@2x.png"),
            (29, 3, "Icon-App-29x29@3x.png"),
            (40, 1, "Icon-App-40x40@1x.png"),
            (40, 2, "Icon-App-40x40@2x.png"),
            (40, 3, "Icon-App-40x40@3x.png"),
            (60, 2, "Icon-App-60x60@2x.png"),
            (60, 3, "Icon-App-60x60@3x.png"),
            (76, 1, "Icon-App-76x76@1x.png"),
            (76, 2, "Icon-App-76x76@2x.png"),
            (83.5, 2, "Icon-App-83.5x83.5@2x.png"),
        ]:
            save_png(ios_dir / filename, int(size * scale))

    ico_path = root / "windows/runner/resources/app_icon.ico"
    src.save(
        ico_path,
        format="ICO",
        sizes=[
            (16, 16),
            (24, 24),
            (32, 32),
            (48, 48),
            (64, 64),
            (128, 128),
            (256, 256),
        ],
    )
    print(f"wrote {ico_path}")

    save_png(root / "linux/runner/resources/app_icon.png", 256)
    print("done")


if __name__ == "__main__":
    main()
