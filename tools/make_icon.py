#!/usr/bin/env python3
"""生成 iOS 全套 App 图标。

图形取自品牌图：深藏青底 + 洋红半圆拱。
iOS 要求图标是**不透明、无圆角**的满幅方图（系统自己裁圆角），
所以这里按原图比例重绘，而不是直接缩放那张带透明圆角的图。
"""
from PIL import Image, ImageDraw
import json, os

# ——— 品牌色与几何（按 512 原图测得）———
NAVY = (7, 17, 53)        # #071135
RED = (210, 2, 60)        # #D2023C
REF = 512.0
CX, CY = 255.5, 313.0     # 拱门圆心（底边中点）
R_OUT, R_IN = 153.0, 67.5  # 外半径 / 内半径

MASTER = 1024
SS = 4                    # 超采样倍数，消除斜边锯齿

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "..", "BizApp", "Assets.xcassets", "AppIcon.appiconset")


def draw(size):
    s = size * SS
    k = s / REF  # 以 512 为基准放大
    img = Image.new("RGB", (s, s), NAVY)
    d = ImageDraw.Draw(img)

    def box(r):
        return [CX * k - r * k, CY * k - r * k, CX * k + r * k, CY * k + r * k]

    # 上半圆（180°→360°，PIL 角度以 3 点方向为 0、顺时针增加）
    d.pieslice(box(R_OUT), 180, 360, fill=RED)
    # 挖掉内圈，形成拱
    d.pieslice(box(R_IN), 180, 360, fill=NAVY)

    return img.resize((size, size), Image.LANCZOS)


def main():
    master = draw(MASTER)
    specs = [
        ("Icon-20@2x.png", 40), ("Icon-20@3x.png", 60),
        ("Icon-29@2x.png", 58), ("Icon-29@3x.png", 87),
        ("Icon-40@2x.png", 80), ("Icon-40@3x.png", 120),
        ("Icon-60@2x.png", 120), ("Icon-60@3x.png", 180),
        ("Icon-1024.png", 1024),
    ]
    for name, px in specs:
        src = master if px == 1024 else draw(px)
        src.save(os.path.join(ASSETS, name), "PNG")

    pairs = [
        ("20x20", "2x", "Icon-20@2x.png"), ("20x20", "3x", "Icon-20@3x.png"),
        ("29x29", "2x", "Icon-29@2x.png"), ("29x29", "3x", "Icon-29@3x.png"),
        ("40x40", "2x", "Icon-40@2x.png"), ("40x40", "3x", "Icon-40@3x.png"),
        ("60x60", "2x", "Icon-60@2x.png"), ("60x60", "3x", "Icon-60@3x.png"),
    ]
    contents = {"images": [], "info": {"author": "xcode", "version": 1}}
    for size, scale, fn in pairs:
        contents["images"].append({"size": size, "idiom": "iphone", "filename": fn, "scale": scale})
    contents["images"].append({"size": "1024x1024", "idiom": "ios-marketing",
                               "filename": "Icon-1024.png", "scale": "1x"})
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    master.save(os.path.join(os.path.dirname(ASSETS), "..", "..", "AppIcon-512.png"))
    print("icons ok ->", ASSETS)


if __name__ == "__main__":
    main()
