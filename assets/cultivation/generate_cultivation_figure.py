from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os
import random

TEXT_COLOR = (35, 35, 35, 255)
TEXT_STROKE_COLOR = (24, 22, 20, 90)
BASE_SIZE = 200


def load_ui_font(size):
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    font_path = os.path.join(project_root, "assets", "fonts", "SourceHanSansSC-VF.ttf")
    font = ImageFont.truetype(font_path, size=size)
    if hasattr(font, "set_variation_by_axes"):
        try:
            font.set_variation_by_axes([300])
        except Exception:
            pass
    return font


def draw_centered_status_text(image, center_x, center_y, text):
    draw = ImageDraw.Draw(image)
    scale = image.size[0] / BASE_SIZE
    font_size = max(11, int(round(17 * scale * (2.0 / 3.0))))
    stroke_width = 1
    font = load_ui_font(font_size)
    text_bbox = draw.textbbox((0, 0), text, font=font, stroke_width=stroke_width)
    text_x = center_x - (text_bbox[0] + text_bbox[2]) / 2
    text_y = center_y - (text_bbox[1] + text_bbox[3]) / 2 - max(1, int(round(scale * 0.5)))
    draw.text(
        (text_x, text_y),
        text,
        font=font,
        fill=TEXT_COLOR,
        stroke_width=stroke_width,
        stroke_fill=TEXT_STROKE_COLOR,
    )


def draw_ink_blot(draw, x, y, size, opacity=150):
    """绘制水墨晕染效果"""
    for i in range(5):
        r = size * (1 + i * 0.3)
        color = (60, 60, 60, max(0, opacity - i * 25))
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def create_cultivation_figure_base(size=(400, 400)):
    """创建水墨风格的修炼小人基础版本（带镂空气海，占满画布）"""
    scale = min(size) / BASE_SIZE

    def s(value):
        return int(round(value * scale))

    temp_img = Image.new("RGBA", size, (0, 0, 0, 0))
    temp_draw = ImageDraw.Draw(temp_img)

    center_x = size[0] // 2
    center_y = size[1] // 2 + s(10)

    head_radius = s(28)
    for i in range(3):
        r = head_radius + s(i * 3)
        alpha = 180 - i * 40
        temp_draw.ellipse(
            [center_x - r, center_y - s(60) - r, center_x + r, center_y - s(60) + r],
            fill=(50, 50, 50, alpha),
        )
    temp_draw.ellipse(
        [center_x - head_radius, center_y - s(60) - head_radius, center_x + head_radius, center_y - s(60) + head_radius],
        fill=(35, 35, 35, 210),
    )

    eye_y = center_y - s(60)
    temp_draw.polygon(
        [
            (center_x - s(15), eye_y - s(1)),
            (center_x - s(9), eye_y - s(3)),
            (center_x - s(7), eye_y),
            (center_x - s(9), eye_y + s(2)),
            (center_x - s(15), eye_y + s(1)),
        ],
        fill=(8, 8, 8, 255),
    )
    temp_draw.polygon(
        [
            (center_x + s(15), eye_y - s(1)),
            (center_x + s(9), eye_y - s(3)),
            (center_x + s(7), eye_y),
            (center_x + s(9), eye_y + s(2)),
            (center_x + s(15), eye_y + s(1)),
        ],
        fill=(8, 8, 8, 255),
    )

    temp_draw.ellipse([center_x - s(12), eye_y - s(1), center_x - s(10), eye_y + s(1)], fill=(100, 100, 100, 240))
    temp_draw.ellipse([center_x + s(10), eye_y - s(1), center_x + s(12), eye_y + s(1)], fill=(100, 100, 100, 240))

    temp_draw.line(
        [center_x - s(16), eye_y - s(5), center_x - s(5), eye_y - s(2)],
        fill=(5, 5, 5, 230),
        width=max(1, s(3)),
    )
    temp_draw.line(
        [center_x + s(5), eye_y - s(2), center_x + s(16), eye_y - s(5)],
        fill=(5, 5, 5, 230),
        width=max(1, s(3)),
    )
    temp_draw.line(
        [center_x - s(14), eye_y + s(2), center_x - s(8), eye_y + s(3)],
        fill=(10, 10, 10, 150),
        width=max(1, s(1)),
    )
    temp_draw.line(
        [center_x + s(8), eye_y + s(3), center_x + s(14), eye_y + s(2)],
        fill=(10, 10, 10, 150),
        width=max(1, s(1)),
    )

    body_points = [
        (center_x - s(24), center_y - s(30)),
        (center_x + s(24), center_y - s(30)),
        (center_x + s(32), center_y + s(30)),
        (center_x + s(20), center_y + s(50)),
        (center_x, center_y + s(43)),
        (center_x - s(20), center_y + s(50)),
        (center_x - s(32), center_y + s(30)),
    ]
    temp_draw.polygon(body_points, fill=(35, 35, 35, 210))

    left_leg = [
        (center_x - s(25), center_y + s(23)),
        (center_x - s(50), center_y + s(40)),
        (center_x - s(58), center_y + s(60)),
        (center_x - s(40), center_y + s(75)),
        (center_x - s(15), center_y + s(67)),
        (center_x - s(8), center_y + s(47)),
    ]
    temp_draw.polygon(left_leg, fill=(40, 40, 40, 200))

    right_leg = [
        (center_x + s(25), center_y + s(23)),
        (center_x + s(50), center_y + s(40)),
        (center_x + s(58), center_y + s(60)),
        (center_x + s(40), center_y + s(75)),
        (center_x + s(15), center_y + s(67)),
        (center_x + s(8), center_y + s(47)),
    ]
    temp_draw.polygon(right_leg, fill=(40, 40, 40, 200))

    left_arm = [
        (center_x - s(25), center_y - s(15)),
        (center_x - s(45), center_y + s(3)),
        (center_x - s(40), center_y + s(23)),
        (center_x - s(15), center_y + s(15)),
    ]
    temp_draw.polygon(left_arm, fill=(35, 35, 35, 200))

    right_arm = [
        (center_x + s(25), center_y - s(15)),
        (center_x + s(45), center_y + s(3)),
        (center_x + s(40), center_y + s(23)),
        (center_x + s(15), center_y + s(15)),
    ]
    temp_draw.polygon(right_arm, fill=(35, 35, 35, 200))

    temp_draw.ellipse([center_x - s(13), center_y + s(9), center_x + s(13), center_y + s(33)], fill=(30, 30, 30, 220))

    draw_ink_blot(temp_draw, center_x - s(75), center_y - s(20), s(10), 80)
    draw_ink_blot(temp_draw, center_x + s(75), center_y - s(20), s(10), 80)
    draw_ink_blot(temp_draw, center_x, center_y + s(85), s(12), 70)

    return temp_img, center_x, center_y, scale


def create_cultivation_figure(size=(400, 400)):
    """创建水墨风格的修炼小人（带镂空气海）"""
    temp_img, center_x, center_y, scale = create_cultivation_figure_base(size)
    final_img = Image.new("RGBA", size, (0, 0, 0, 0))
    final_img.paste(temp_img, (0, 0), temp_img)

    final_draw = ImageDraw.Draw(final_img)
    dantian_radius = int(round(26 * scale))
    dantian_center_y = center_y + int(round(10 * scale))
    final_draw.ellipse(
        [center_x - dantian_radius, dantian_center_y - dantian_radius, center_x + dantian_radius, dantian_center_y + dantian_radius],
        fill=(0, 0, 0, 0),
    )

    final_img = final_img.filter(ImageFilter.GaussianBlur(radius=max(0.35, 0.45 * scale)))
    draw_centered_status_text(final_img, center_x, dantian_center_y, "未修炼")
    return final_img


def create_cultivation_figure_with_particles(size=(400, 400)):
    """创建水墨风格的修炼小人（带蓝色粒子光效，气海镂空）"""
    temp_img, center_x, center_y, scale = create_cultivation_figure_base(size)
    final_img = Image.new("RGBA", size, (0, 0, 0, 0))
    final_draw = ImageDraw.Draw(final_img)

    num_particles = 70
    particles_added = 0
    max_attempts = 500

    while particles_added < num_particles and max_attempts > 0:
        max_attempts -= 1
        angle = random.uniform(0, 2 * math.pi)
        distance = random.uniform(50 * scale, 95 * scale)
        x = center_x + int(distance * math.cos(angle))
        y = center_y + int(distance * math.sin(angle))

        face_top = center_y - int(round(90 * scale))
        face_bottom = center_y - int(round(30 * scale))
        face_left = center_x - int(round(40 * scale))
        face_right = center_x + int(round(40 * scale))
        if face_top <= y <= face_bottom and face_left <= x <= face_right:
            continue

        particle_size = random.uniform(1.5 * scale, 4 * scale)
        alpha = random.randint(40, 150)
        blue_variation = random.randint(-20, 20)
        color = (80 + blue_variation, 140 + blue_variation, 220 + blue_variation, alpha)
        final_draw.ellipse(
            [x - particle_size, y - particle_size, x + particle_size, y + particle_size],
            fill=color,
        )
        particles_added += 1

    final_img.paste(temp_img, (0, 0), temp_img)

    dantian_radius = int(round(26 * scale))
    dantian_center_y = center_y + int(round(10 * scale))
    final_draw.ellipse(
        [center_x - dantian_radius, dantian_center_y - dantian_radius, center_x + dantian_radius, dantian_center_y + dantian_radius],
        fill=(0, 0, 0, 0),
    )

    final_img = final_img.filter(ImageFilter.GaussianBlur(radius=max(0.35, 0.45 * scale)))
    draw_centered_status_text(final_img, center_x, dantian_center_y, "修炼中")
    return final_img


def main():
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    output_dir = os.path.join(project_root, "assets", "cultivation")
    os.makedirs(output_dir, exist_ok=True)

    figure_size = (400, 400)

    figure = create_cultivation_figure(figure_size)
    figure.save(f"{output_dir}/cultivation_figure.png")
    print("生成修炼状态素材（带镂空气海）: cultivation_figure.png")

    figure_particles = create_cultivation_figure_with_particles(figure_size)
    figure_particles.save(f"{output_dir}/cultivation_figure_particles.png")
    print("生成修炼状态素材（带蓝色粒子光效）: cultivation_figure_particles.png")


if __name__ == "__main__":
    main()
