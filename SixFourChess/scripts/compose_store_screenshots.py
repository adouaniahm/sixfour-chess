#!/usr/bin/env python3
"""
Compose App Store-ready screenshots from raw UI-test captures.

Input:
  screenshots_export/*.png

Output:
  screenshots_store_ready/<lang>/*.png

The script exports fixed 6.5-inch App Store dimensions (1284x2778) and adds:
  - warm editorial background
  - localized title
  - localized subtitle
  - framed screenshot card with subtle shadow
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Tuple

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "screenshots_export"
OUTPUT_DIR = ROOT / "screenshots_store_ready"

TITLE_FONT = "/Library/Fonts/SF-Pro-Display-Bold.otf"
SUBTITLE_FONT = "/Library/Fonts/SF-Pro-Text-Medium.otf"
BADGE_FONT = "/Library/Fonts/SF-Pro-Text-Semibold.otf"

BACKGROUND_TOP = "#F5ECDD"
BACKGROUND_BOTTOM = "#E7D5BE"
TEXT_PRIMARY = "#2B2017"
TEXT_SECONDARY = "#6C5647"
BADGE_FILL = "#F7F2EA"
BADGE_STROKE = "#CFB89E"
CARD_FILL = "#FFF9F2"
CARD_STROKE = "#E3D0BC"
CANVAS_SIZE = (1284, 2778)


@dataclass(frozen=True)
class CopyBlock:
    badge: str
    title: str
    subtitle: str


COPY: Dict[str, Dict[str, CopyBlock]] = {
    "en": {
        "01_GameBoard": CopyBlock("SixFour", "Chess, made simple", "Focused local play against the AI."),
        "02_HintSystem": CopyBlock("Guidance", "3 hints per game", "Get clear help when you need your next move."),
        "03_Settings": CopyBlock("Control", "A clear, polished experience", "Adjust difficulty, sound, feedback, and privacy."),
        "04_PlayedGames": CopyBlock("History", "Your finished games stay here", "Keep a local record of your completed matches."),
        "05_Replay": CopyBlock("Replay", "Replay every move", "Step through the game directly on the board."),
    },
    "fr": {
        "01_GameBoard": CopyBlock("SixFour", "Les échecs, simplement", "Jouez localement contre l’IA, sans distraction."),
        "02_HintSystem": CopyBlock("Aide", "3 aides par partie", "Obtenez un conseil clair pour votre prochain coup."),
        "03_Settings": CopyBlock("Réglages", "Une expérience claire et soignée", "Ajustez difficulté, sons, retours et confidentialité."),
        "04_PlayedGames": CopyBlock("Historique", "Vos parties terminées restent ici", "Retrouvez l’historique local de vos parties jouées."),
        "05_Replay": CopyBlock("Replay", "Rejouez chaque coup", "Revivez la partie directement sur l’échiquier."),
    },
    "it": {
        "01_GameBoard": CopyBlock("SixFour", "Scacchi, in semplicità", "Gioca localmente contro l’IA, senza distrazioni."),
        "02_HintSystem": CopyBlock("Aiuto", "3 aiuti per partita", "Ricevi un consiglio chiaro per la tua prossima mossa."),
        "03_Settings": CopyBlock("Impostazioni", "Un’esperienza chiara e curata", "Regola difficoltà, suoni, feedback e privacy."),
        "04_PlayedGames": CopyBlock("Storico", "Le tue partite concluse restano qui", "Ritrova lo storico locale delle partite giocate."),
        "05_Replay": CopyBlock("Replay", "Rivedi ogni mossa", "Rivivi la partita direttamente sulla scacchiera."),
    },
}


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def vertical_gradient(size: Tuple[int, int], top: str, bottom: str) -> Image.Image:
    width, height = size
    base = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(base)
    top_rgb = ImageColor.getrgb(top)
    bottom_rgb = ImageColor.getrgb(bottom)
    for y in range(height):
        t = y / max(height - 1, 1)
        rgb = tuple(int(top_rgb[i] + (bottom_rgb[i] - top_rgb[i]) * t) for i in range(3))
        draw.line((0, y, width, y), fill=rgb)
    return base


def rounded_mask(size: Tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def fit_text(draw: ImageDraw.ImageDraw, text: str, font_path: str, max_size: int, min_size: int, max_width: int) -> ImageFont.FreeTypeFont:
    for size in range(max_size, min_size - 1, -2):
        font = load_font(font_path, size)
        bbox = draw.textbbox((0, 0), text, font=font)
        if bbox[2] - bbox[0] <= max_width:
            return font
    return load_font(font_path, min_size)


def add_badge(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, width: int) -> int:
    font = load_font(BADGE_FONT, 42)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    padding_x = 34
    padding_y = 18
    badge_w = min(width, text_width + padding_x * 2)
    badge_h = text_height + padding_y * 2
    draw.rounded_rectangle((x, y, x + badge_w, y + badge_h), radius=badge_h // 2, fill=BADGE_FILL, outline=BADGE_STROKE, width=3)
    draw.text((x + padding_x, y + padding_y - 2), text, font=font, fill=TEXT_SECONDARY)
    return y + badge_h


def compose(raw_path: Path) -> Path:
    lang, screen_id = raw_path.stem.split("_", 1)
    if lang not in COPY or screen_id not in COPY[lang]:
        raise ValueError(f"Unsupported screenshot name: {raw_path.name}")

    copy = COPY[lang][screen_id]
    screenshot = Image.open(raw_path).convert("RGB")
    width, height = CANVAS_SIZE

    canvas = vertical_gradient((width, height), BACKGROUND_TOP, BACKGROUND_BOTTOM)
    draw = ImageDraw.Draw(canvas)

    horizontal_margin = int(width * 0.075)
    top_margin = int(height * 0.065)
    content_width = width - horizontal_margin * 2

    badge_bottom = add_badge(draw, copy.badge, horizontal_margin, top_margin, content_width)

    title_font = fit_text(draw, copy.title, TITLE_FONT, max_size=int(width * 0.07), min_size=54, max_width=content_width)
    title_bbox = draw.textbbox((0, 0), copy.title, font=title_font)
    title_y = badge_bottom + int(height * 0.024)
    draw.text((horizontal_margin, title_y), copy.title, font=title_font, fill=TEXT_PRIMARY)

    subtitle_font = fit_text(draw, copy.subtitle, SUBTITLE_FONT, max_size=int(width * 0.032), min_size=28, max_width=content_width)
    subtitle_bbox = draw.textbbox((0, 0), copy.subtitle, font=subtitle_font)
    subtitle_y = title_y + (title_bbox[3] - title_bbox[1]) + int(height * 0.014)
    draw.text((horizontal_margin, subtitle_y), copy.subtitle, font=subtitle_font, fill=TEXT_SECONDARY)

    text_block_bottom = subtitle_y + (subtitle_bbox[3] - subtitle_bbox[1])
    card_top = text_block_bottom + int(height * 0.045)
    bottom_margin = int(height * 0.06)
    card_height = height - card_top - bottom_margin
    card_width = content_width
    card_x = horizontal_margin
    card_y = card_top

    shadow = Image.new("RGBA", (card_width, card_height), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((14, 22, card_width - 14, card_height - 6), radius=44, fill=(43, 32, 23, 55))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.paste(shadow, (card_x, card_y), shadow)

    card = Image.new("RGBA", (card_width, card_height), (255, 255, 255, 0))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle((0, 0, card_width - 1, card_height - 1), radius=44, fill=CARD_FILL, outline=CARD_STROKE, width=3)

    inner_margin = int(card_width * 0.026)
    target_w = card_width - inner_margin * 2
    target_h = card_height - inner_margin * 2

    resized = screenshot.copy()
    resized.thumbnail((target_w, target_h), Image.Resampling.LANCZOS)
    image_x = (card_width - resized.width) // 2
    image_y = (card_height - resized.height) // 2

    screenshot_mask = rounded_mask(resized.size, radius=22)
    card.paste(resized, (image_x, image_y), screenshot_mask)

    canvas.paste(card, (card_x, card_y), card)

    out_dir = OUTPUT_DIR / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{raw_path.stem}_store.png"
    canvas.save(out_path, format="PNG")
    return out_path


def main() -> None:
    if not RAW_DIR.exists():
        raise SystemExit(f"Input directory not found: {RAW_DIR}")

    pngs = sorted(RAW_DIR.glob("*.png"))
    if not pngs:
        raise SystemExit(f"No PNG screenshots found in: {RAW_DIR}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    generated = [compose(path) for path in pngs]

    print(f"Generated {len(generated)} composed screenshots:")
    for path in generated:
        print(path)


if __name__ == "__main__":
    main()
