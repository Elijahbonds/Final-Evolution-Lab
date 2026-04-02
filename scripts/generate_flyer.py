#!/usr/bin/env python3
"""Generate the Final Evolution Lab marketing flyer as a professional PDF."""

import qrcode
from reportlab.lib.pagesizes import letter
from reportlab.lib.units import inch
from reportlab.lib.colors import HexColor, white, black
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from io import BytesIO
import os

OUTPUT_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "FINAL_EVOLUTION_LAB_FLYER.pdf")

# Colors
DARK_BG = HexColor("#0a0a1a")
ACCENT_ORANGE = HexColor("#ff6b35")
ACCENT_BLUE = HexColor("#00d4ff")
ACCENT_PURPLE = HexColor("#9b59b6")
DARK_CARD = HexColor("#1a1a2e")
TEXT_WHITE = HexColor("#ffffff")
TEXT_GRAY = HexColor("#b0b0b0")
ACCENT_GREEN = HexColor("#00e676")

def generate_qr_code():
    """Generate QR code with UTM tracking."""
    url = "https://finalevolutiongroup.com?utm_source=flyer&utm_campaign=hoopbus_vbl"
    qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=10, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0a0a1a", back_color="#ffffff")
    buf = BytesIO()
    img.save(buf, format='PNG')
    buf.seek(0)
    return buf

def draw_rounded_rect(c, x, y, w, h, r, fill_color):
    """Draw a rounded rectangle."""
    c.setFillColor(fill_color)
    p = c.beginPath()
    p.moveTo(x + r, y)
    p.lineTo(x + w - r, y)
    p.arcTo(x + w - r, y, x + w, y + r, 90)
    p.lineTo(x + w, y + h - r)
    p.arcTo(x + w, y + h - r, x + w - r, y + h, 0)
    p.lineTo(x + r, y + h)
    p.arcTo(x + r, y + h, x, y + h - r, -90)
    p.lineTo(x, y + r)
    p.arcTo(x, y + r, x + r, y, 180)
    p.close()
    c.drawPath(p, fill=1, stroke=0)

def create_flyer():
    w, h = letter  # 8.5 x 11 inches
    c = canvas.Canvas(OUTPUT_PATH, pagesize=letter)
    
    # ── Background ──
    c.setFillColor(DARK_BG)
    c.rect(0, 0, w, h, fill=1, stroke=0)
    
    # ── Gradient-like top accent bar ──
    for i in range(60):
        alpha = 1.0 - (i / 60.0)
        r_val = int(0xff * alpha + 0x0a * (1 - alpha))
        g_val = int(0x6b * alpha)
        b_val = int(0x35 * alpha + 0x1a * (1 - alpha))
        c.setFillColor(HexColor(f"#{r_val:02x}{g_val:02x}{b_val:02x}"))
        c.rect(0, h - 3 - i * 1.5, w, 1.5, fill=1, stroke=0)
    
    # ── Top accent line ──
    c.setFillColor(ACCENT_ORANGE)
    c.rect(0, h - 3, w, 3, fill=1, stroke=0)
    
    y = h - 50
    
    # ── Logo / Title Area ──
    c.setFillColor(TEXT_WHITE)
    c.setFont("Helvetica-Bold", 42)
    c.drawCentredString(w/2, y, "FINAL EVOLUTION")
    y -= 45
    
    c.setFont("Helvetica-Bold", 48)
    c.setFillColor(ACCENT_ORANGE)
    c.drawCentredString(w/2, y, "LAB")
    y -= 8
    
    # Underline accent
    c.setStrokeColor(ACCENT_BLUE)
    c.setLineWidth(2)
    c.line(w/2 - 40, y, w/2 + 40, y)
    y -= 30
    
    # ── Tagline ──
    c.setFillColor(ACCENT_BLUE)
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(w/2, y, "THE FUTURE OF SPORTS TRAINING IS HERE")
    y -= 15
    
    c.setFillColor(TEXT_GRAY)
    c.setFont("Helvetica", 11)
    c.drawCentredString(w/2, y, "AI-Powered • Real-Time Streaming • Unreal Engine 5")
    y -= 45
    
    # ── Feature Cards (2x2 grid) ──
    features = [
        ("🏀", "17 Game Modes", "Basketball, Soccer, Karate,\nTennis, Golf, Surfing & more"),
        ("🌍", "12 AI Environments", "Venice Beach, Cyberpunk Gym,\nZen Dojo, Neon Arcade & more"),
        ("🎮", "Real-Time Streaming", "Play instantly in your browser\nNo download required"),
        ("💪", "Pro Training", "23 exercises with 3D animation\n54 motion-captured moves"),
    ]
    
    card_w = 240
    card_h = 100
    gap = 20
    start_x = (w - card_w * 2 - gap) / 2
    
    for i, (icon, title, desc) in enumerate(features):
        col = i % 2
        row = i // 2
        cx = start_x + col * (card_w + gap)
        cy = y - row * (card_h + gap)
        
        # Card background
        draw_rounded_rect(c, cx, cy - card_h + 15, card_w, card_h, 8, DARK_CARD)
        
        # Card border accent
        c.setStrokeColor(ACCENT_BLUE if col == 0 else ACCENT_ORANGE)
        c.setLineWidth(1.5)
        c.roundRect(cx, cy - card_h + 15, card_w, card_h, 8, fill=0, stroke=1)
        
        # Title
        c.setFillColor(TEXT_WHITE)
        c.setFont("Helvetica-Bold", 14)
        c.drawString(cx + 15, cy - 8, title)
        
        # Description
        c.setFillColor(TEXT_GRAY)
        c.setFont("Helvetica", 9.5)
        lines = desc.split('\n')
        for j, line in enumerate(lines):
            c.drawString(cx + 15, cy - 25 - j * 13, line)
    
    y -= 2 * (card_h + gap) + 20
    
    # ── QR Code Section ──
    qr_size = 170
    qr_buf = generate_qr_code()
    qr_img = ImageReader(qr_buf)
    
    # QR background box
    qr_box_w = 220
    qr_box_h = 250
    qr_x = (w - qr_box_w) / 2
    qr_y = y - qr_box_h + 10
    
    draw_rounded_rect(c, qr_x, qr_y, qr_box_w, qr_box_h, 12, DARK_CARD)
    
    # QR border
    c.setStrokeColor(ACCENT_GREEN)
    c.setLineWidth(2)
    c.roundRect(qr_x, qr_y, qr_box_w, qr_box_h, 12, fill=0, stroke=1)
    
    # QR Code image
    qr_img_x = qr_x + (qr_box_w - qr_size) / 2
    qr_img_y = qr_y + 50
    c.drawImage(qr_img, qr_img_x, qr_img_y, qr_size, qr_size)
    
    # "SCAN TO PLAY" text
    c.setFillColor(ACCENT_GREEN)
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(w/2, qr_y + 25, "SCAN TO PLAY")
    
    c.setFillColor(TEXT_GRAY)
    c.setFont("Helvetica", 10)
    c.drawCentredString(w/2, qr_y + 10, "finalevolutiongroup.com")
    
    y = qr_y - 25
    
    # ── Event Info ──
    c.setFillColor(ACCENT_ORANGE)
    c.setFont("Helvetica-Bold", 14)
    c.drawCentredString(w/2, y, "🏟️  COMING TO HOOPBUS & VBL EVENTS  🏟️")
    y -= 20
    
    c.setFillColor(TEXT_GRAY)
    c.setFont("Helvetica", 10)
    c.drawCentredString(w/2, y, "Venice Beach • Muscle Beach • Basketball Courts Nationwide")
    y -= 35
    
    # ── Tech badges row ──
    badges = ["Unreal Engine 5", "AI-Generated", "Pixel Streaming", "Cross-Platform"]
    badge_w = 115
    total_badges_w = len(badges) * badge_w + (len(badges) - 1) * 8
    bx = (w - total_badges_w) / 2
    
    for badge_text in badges:
        draw_rounded_rect(c, bx, y - 5, badge_w, 22, 11, HexColor("#2a2a3e"))
        c.setFillColor(ACCENT_BLUE)
        c.setFont("Helvetica-Bold", 8)
        c.drawCentredString(bx + badge_w/2, y, badge_text)
        bx += badge_w + 8
    
    y -= 40
    
    # ── Bottom bar ──
    c.setFillColor(HexColor("#0d0d20"))
    c.rect(0, 0, w, 45, fill=1, stroke=0)
    c.setFillColor(ACCENT_ORANGE)
    c.rect(0, 45, w, 1.5, fill=1, stroke=0)
    
    c.setFillColor(TEXT_GRAY)
    c.setFont("Helvetica", 8)
    c.drawCentredString(w/2, 28, "Final Evolution Lab © 2026  |  @finalevolutionlab  |  Built with Unreal Engine 5")
    c.drawCentredString(w/2, 14, "Powered by AI: Meshy • Luma AI • DeepMotion • OpenArt")
    
    c.save()
    print(f"✅ Flyer generated: {OUTPUT_PATH}")

if __name__ == "__main__":
    create_flyer()
