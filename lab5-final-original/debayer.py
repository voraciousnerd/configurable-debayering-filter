#!/usr/bin/env python3
import sys
import os
import matplotlib.pyplot as plt
import numpy as np

N = int(sys.argv[1]) if len(sys.argv) > 1 else 32

input_filename = f"input_N{N}x{N}.txt"

if not os.path.exists(input_filename):
    print(f"Error: {input_filename} not found!")
    sys.exit(1)

with open(input_filename, "r") as f:
    pixels = [int(line.strip()) for line in f if line.strip()]

if len(pixels) < N * N:
    print(f"Error: Found only {len(pixels)} pixels, but {N}x{N}={N*N} are required.")
    sys.exit(1)

def img(r, c):
    if r < 0 or r >= N or c < 0 or c >= N:
        return 0
    return pixels[r * N + c]

rgb_pixels = []

with open(f"reference_N{N}x{N}.txt", "w") as f:
    for r in range(N):
        for c in range(N):
            if r % 2 == 0 and c % 2 == 0:          # case i : G
                G = img(r, c)
                R = (img(r-1, c) + img(r+1, c)) // 2
                B = (img(r, c-1) + img(r, c+1)) // 2
            elif r % 2 == 0 and c % 2 == 1:         # case ii: B
                B = img(r, c)
                G = (img(r-1,c) + img(r+1,c) + img(r,c-1) + img(r,c+1)) // 4
                R = (img(r-1,c-1) + img(r-1,c+1) + img(r+1,c-1) + img(r+1,c+1)) // 4
            elif r % 2 == 1 and c % 2 == 0:         # case iii: R
                R = img(r, c)
                G = (img(r-1,c) + img(r+1,c) + img(r,c-1) + img(r,c+1)) // 4
                B = (img(r-1,c-1) + img(r-1,c+1) + img(r+1,c-1) + img(r+1,c+1)) // 4
            else:                                   # case iv : G
                G = img(r, c)
                R = (img(r, c-1) + img(r, c+1)) // 2
                B = (img(r-1, c) + img(r+1, c)) // 2
            
            f.write(f"{R} {G} {B}\n")
            rgb_pixels.append([R, G, B])

print(f"Processed {input_filename} and generated reference_N{N}x{N}.txt for {N}x{N} image.")

"""
bayer_img = np.array(pixels[:N*N]).reshape((N, N))
rgb_img = np.array(rgb_pixels).reshape((N, N, 3)).astype(np.uint8)

fig, axes = plt.subplots(1, 2, figsize=(12, 6))

axes[0].imshow(bayer_img, cmap='gray')
axes[0].set_title(f"Before: Bayer Pattern ({N}x{N})")
axes[0].axis('off')

axes[1].imshow(rgb_img)
axes[1].set_title(f"After: Debayered RGB ({N}x{N})")
axes[1].axis('off')

plt.tight_layout()
plt.show()
"""