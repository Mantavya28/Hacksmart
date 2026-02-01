import cv2
import numpy as np
import os

def process_pixel_logo():
    input_path = "greenswap_logo_pixel.png"
    output_path = "greenswap_logo.png"

    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found.")
        return

    try:
        img = cv2.imread(input_path)
        if img is None:
            print("Error: Could not load image.")
            return

        # 1. Background Removal for Pixel Art
        # Background is white. Logo is dark/colorful.
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Binary Threshold (Strict). 
        # Any white background (>240) becomes transparent.
        # We use THRESH_BINARY_INV so background becomes 0 (black/transparent) and logo becomes 255 (white/opaque)
        _, mask = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)
        
        # 2. Contour Detection to Crop
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            print("No contours found.")
            return
            
        c = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(c)
        
        # 3. Create Alpha Channel
        # For pixel art, we do NOT want antialiasing (blur). We want sharp edges.
        # So we use the binary mask directly as the alpha channel.
        
        b, g, r = cv2.split(img)
        rgba = [b, g, r, mask]
        dst = cv2.merge(rgba, 4)
        
        # 4. Crop
        # Add 0 padding to keep it tight
        crop = dst[y:y+h, x:x+w]
        
        # 5. Save
        cv2.imwrite(output_path, crop)
        print("Success: Pixel Art Logo processed (Sharp Edges).")
        
    except Exception as e:
        print(f"Failed: {e}")

if __name__ == "__main__":
    process_pixel_logo()
