import os
from PIL import Image

def resize_image(source_path, target_path, size):
    """Resize image to specified size and save it."""
    # Ensure target directory exists
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    with Image.open(source_path) as img:
        # Check if the image has an alpha channel
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
            
        # Use high-quality resampling filter (Resampling.LANCZOS)
        resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
        resized_img.save(target_path, 'PNG')
        print(f"Generated: {target_path} ({size}x{size})")

def main():
    source_logo = r"assets/images/mobitrail_logo.png"
    if not os.path.exists(source_logo):
        print(f"Error: Source logo not found at {source_logo}")
        return

    # Android mipmaps configurations (density name, size in pixels)
    android_configs = [
        ("mdpi", 48),
        ("hdpi", 72),
        ("xhdpi", 96),
        ("xxhdpi", 144),
        ("xxxhdpi", 192),
    ]

    print("--- Generating Android Launcher Icons ---")
    for density, size in android_configs:
        # Standard launcher icon
        target_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        resize_image(source_logo, target_path, size)
        
        # Round launcher icon
        target_round_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png"
        resize_image(source_logo, target_round_path, size)

    # iOS appiconset configurations (filename, size in pixels)
    ios_configs = [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]

    print("\n--- Generating iOS App Icons ---")
    ios_base_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for filename, size in ios_configs:
        target_path = os.path.join(ios_base_dir, filename)
        resize_image(source_logo, target_path, size)

    print("\nIcon generation complete!")

if __name__ == "__main__":
    main()
