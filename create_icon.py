from PIL import Image, ImageDraw
import math

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    
    # Scale factor
    s = size / 512.0
    
    orange = (242, 135, 30)
    blue = (74, 174, 217)
    light_blue = (123, 200, 232)
    
    # 8 orange petals
    petal_len = int(55 * s)
    petal_w = int(22 * s)
    for i in range(8):
        angle = math.radians(i * 45)
        # Outer tip of petal
        dist_outer = int(200 * s)
        dist_inner = int(120 * s)
        
        ox = cx + int(dist_outer * math.cos(angle))
        oy = cy + int(dist_outer * math.sin(angle))
        ix = cx + int(dist_inner * math.cos(angle))
        iy = cy + int(dist_inner * math.sin(angle))
        
        # Draw petal as thick line (rotated rectangle)
        perp_angle = angle + math.pi / 2
        hw = int(18 * s)  # half width
        
        points = [
            ix + int(hw * math.cos(perp_angle)),
            iy + int(hw * math.sin(perp_angle)),
            ix - int(hw * math.cos(perp_angle)),
            iy - int(hw * math.sin(perp_angle)),
            ox - int(hw * math.cos(perp_angle)),
            oy - int(hw * math.sin(perp_angle)),
            ox + int(hw * math.cos(perp_angle)),
            oy + int(hw * math.sin(perp_angle)),
        ]
        draw.polygon(points, fill=orange)
    
    # Blue circle (lens) - outer
    r_outer = int(110 * s)
    draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], fill=blue)
    
    # Light blue inner circle
    r_inner = int(80 * s)
    draw.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], fill=light_blue)
    
    # Blue handle (diagonal to bottom-right)
    handle_angle = math.radians(45)
    handle_start = int(115 * s)
    handle_end = int(210 * s)
    handle_w = int(24 * s)
    
    sx = cx + int(handle_start * math.cos(handle_angle))
    sy = cy + int(handle_start * math.sin(handle_angle))
    ex = cx + int(handle_end * math.cos(handle_angle))
    ey = cy + int(handle_end * math.sin(handle_angle))
    
    perp = handle_angle + math.pi / 2
    hw = handle_w // 2
    handle_points = [
        sx + int(hw * math.cos(perp)),
        sy + int(hw * math.sin(perp)),
        sx - int(hw * math.cos(perp)),
        sy - int(hw * math.sin(perp)),
        ex - int(hw * math.cos(perp)),
        ey - int(hw * math.sin(perp)),
        ex + int(hw * math.cos(perp)),
        ey + int(hw * math.sin(perp)),
    ]
    draw.polygon(handle_points, fill=blue)
    
    # Round handle end
    draw.ellipse([ex - hw, ey - hw, ex + hw, ey + hw], fill=blue)
    
    return img

base = r"C:\Users\Mouhamadou toure\Documents\CODE\MOUSSA project\android\app\src\main\res"

sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

for folder, size in sizes.items():
    icon = create_icon(size)
    icon.save(f"{base}\\{folder}\\ic_launcher.png")
    print(f"Saved {folder}/ic_launcher.png ({size}x{size})")

# Also create foreground for adaptive icon (512x512)
fg = create_icon(512)
fg.save(f"{base}\\drawable-v24\\ic_launcher_foreground.png")
print("Saved foreground PNG")

# Create a simple square version for non-adaptive
icon_512 = create_icon(512)
icon_512.save(f"{base}\\drawable\\ic_launcher.png")
print("Done!")
