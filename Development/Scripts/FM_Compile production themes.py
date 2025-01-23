import os
import zipfile
import configparser
import shutil
import re
from PIL import Image, ImageDraw, ImageFont

from reaper_python import *

root_path = RPR_GetExtState("fm4_adjuster", "py_root_path")
master_theme = "Dark SI"
rtconfig_path = 'rtconfig.txt'
master_theme_name = "Flat Madness Ultimate.ReaperThemeZip"
master_theme_config_name = "Flat Madness Ultimate.theme"
rtconfig_content = None

def log(msg):
    RPR_ShowConsoleMsg(str(msg) + "\n")

def is_correct_root_path(path):
    return os.path.exists(os.path.join(path, "Scripts", "FM_Compile production themes.py"))

def create_master_theme(master_theme_path, version):
    log("Creating master theme \"" + master_theme_name + "\" based on \"" + master_theme + "\"...")
    shutil.copy2(master_theme_path, os.path.join(root_path, "..", "ColorThemes", master_theme_name))

    theme_config_path = os.path.join(root_path, "..", "ColorThemes", master_theme_config_name)
    with open(theme_config_path, "r", encoding="utf-8") as theme_config_file:
        content = theme_config_file.read()

    content = re.sub(r'(@version\s+)[0-9.]+', r'\g<1>' + version, content)

    with open(theme_config_path, "w") as file:
        file.write(content)

def create_rtconfig_for_theme(theme_fm_config):
    global rtconfig_content

    if not rtconfig_content:
        with open(os.path.join(root_path, rtconfig_path), "r", encoding="utf-8") as rtconfig_file:
            rtconfig_content = rtconfig_file.read()

    rtconfig_content_local = rtconfig_content

    for key, value in theme_fm_config.items():
        rtconfig_content_local = rtconfig_content_local.replace("{" + key + "}", str(value))

        if "fm_version" in key:
            rtconfig_content_local = rtconfig_content_local.replace("{" + key + "_int}", str(value.replace(".", "")))

    temp_rtconfig_path = os.path.join(root_path, "rtconfig_temp.txt")
    with open(temp_rtconfig_path, "w", encoding="utf-8") as modified_rtconfig_file:
        modified_rtconfig_file.write(rtconfig_content_local)

    return temp_rtconfig_path

def create_zip(theme_file, data_path, theme_rtconfig_path, theme_splash_path, version):
    theme_name = os.path.splitext(theme_file)[0]

    log(f"Compiling production themes v." + version + " for \"" + theme_name + "\"...")

    zip_file_path = os.path.join(root_path, "..", "Utility", "data", theme_name + ".zip")
    with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(os.path.join(root_path, "Themes", theme_file), arcname=theme_file)

        for root, _, files in os.walk(ui_img_path):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, start=data_path)
                zipf.write(file_path, arcname=os.path.join(os.path.basename(data_path), arcname))

        zipf.write(theme_rtconfig_path, arcname=os.path.join(os.path.basename(data_path), rtconfig_path))
        zipf.write(theme_splash_path, arcname=os.path.join(os.path.basename(data_path), 'splash.png'))

    if theme_name == master_theme:
        create_master_theme(zip_file_path, version)

def draw_version_on_splash_image(path, version):
    text = "Ver. " + version

    image = Image.open(path).convert("RGBA")

    font_path = "Tahoma.ttf"
    font_size = 14
    font = ImageFont.truetype(font_path, font_size)

    overlay = Image.new("RGBA", image.size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(overlay)

    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    padding = 7
    box_width = text_width + 2 * padding
    box_height = text_height + 2 * padding

    image_width, image_height = image.size
    box_x = image_width - box_width
    box_y = image_height - box_height

    box_color = (255, 255, 255, 150)

    draw.rounded_rectangle(
        [(box_x, box_y), (box_x + box_width, box_y + box_height)],
        radius=2,
        fill=box_color
    )

    text_x = box_x + padding
    text_y = box_y + padding / 2
    draw.text((text_x, text_y), text, font=font, fill=(255, 255, 255, 0))

    combined = Image.alpha_composite(image, overlay)

    output_path = os.path.join(root_path, "splash.png")

    combined.save(output_path)

    return output_path

def specify_root_path():
    global root_path

    path = root_path

    while not is_correct_root_path(path):
        ret = RPR_GetUserInputs('Path to the \"Development\" directory', 1, 'Enter root path', '', 2000)

        path = str(ret[4]).strip()

        if is_correct_root_path(path) or RPR_MB(path + "\n\nSpecified root path to 'Development' folder is not correct. Please correct path where folders 'Data', 'Scripts', 'Themes' are situated.", "Root path set", 5) != 4:
            break

    if is_correct_root_path(path):
        RPR_SetExtState("fm4_adjuster", "py_root_path", path, True)
        root_path = path


if not is_correct_root_path(root_path):
    specify_root_path()

if is_correct_root_path(root_path):
    for theme_file in os.listdir(os.path.join(root_path, "Themes")):
        if theme_file.endswith(".ReaperTheme"):
            config = configparser.ConfigParser()
            config.read(os.path.join(root_path, "Themes", theme_file), encoding="utf-8")

            try:
                ui_img_folder = config["REAPER"]["ui_img"]
            except KeyError:
                log(f"No ui_img parameter in {theme_file}")
                continue

            ui_img_path = os.path.join(root_path, "Data", ui_img_folder)
            if not os.path.exists(ui_img_path):
                log(f"Folder {ui_img_folder} from {theme_file} does not exists in Data folder")
                continue

            modified_splash_path = draw_version_on_splash_image(os.path.join(ui_img_path, "splash.png"), config["FM"]["fm_version"])
            modified_rtconfig_path = create_rtconfig_for_theme(config["FM"])
            create_zip(theme_file, ui_img_path, modified_rtconfig_path, modified_splash_path, config["FM"]["fm_version"])

            os.remove(modified_rtconfig_path)
            os.remove(modified_splash_path)
else:
    RPR_MB("Root path to Development folder is not set. Please execute script again and specify correct path.", "Root path set", 0)