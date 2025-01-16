import os
import sys
import zipfile
import configparser
import shutil
import re

from reaper_python import *

root_path = "/Users/monolok/Developer/Reaper/FlatMadness/Development"
master_theme = "Dark SI"
rtconfig_path = 'rtconfig.txt'
master_theme_name = "Flat Madness Ultimate.ReaperThemeZip"
master_theme_config_name = "Flat Madness Ultimate.theme"
version = 0

def log(msg):
    RPR_ShowConsoleMsg(str(msg) + "\n")

with open(os.path.join(root_path, rtconfig_path), "r", encoding="utf-8") as rtconfig_file:
    rtconfig_content = rtconfig_file.read()

if not rtconfig_content:
    log("File rtconfig.txt is not found in " + root_path)
    sys.exit()

match = re.search(r"fmversion ([\d.]+)\n", rtconfig_content)
if match:
    version = match.group(1)

def create_master_theme(master_theme_path):
    log("Creating master theme \"" + master_theme_name + "\" based on \"" + master_theme + "\"...")
    shutil.copy2(master_theme_path, os.path.join(root_path, "..", "ColorThemes", master_theme_name))

    theme_config_path = os.path.join(root_path, "..", "ColorThemes", master_theme_config_name)
    with open(theme_config_path, "r", encoding="utf-8") as theme_config_file:
        content = theme_config_file.read()

    content = re.sub(r'(@version\s+)[0-9.]+', r'\g<1>' + version, content)

    with open(theme_config_path, "w") as file:
        file.write(content)

def create_zip(theme_file, data_path, theme_fm_config):
    theme_name = os.path.splitext(theme_file)[0]

    log(f"Compiling production themes v." + version + " for \"" + theme_name + "\"...")

    rtconfig_content_local = rtconfig_content

    for key, value in theme_fm_config.items():
        rtconfig_content_local = rtconfig_content_local.replace("{" + key + "}", str(value))

    modified_rtconfig_path = os.path.join(root_path, "rtconfig_temp.txt")
    with open(modified_rtconfig_path, "w", encoding="utf-8") as modified_rtconfig_file:
        modified_rtconfig_file.write(rtconfig_content_local)

    zip_file_path = os.path.join(root_path, "..", "Utility", "data", theme_name + ".zip")
    with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(os.path.join(root_path, "Themes", theme_file), arcname=theme_file)

        for root, _, files in os.walk(ui_img_path):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, start=data_path)
                zipf.write(file_path, arcname=os.path.join(os.path.basename(data_path), arcname))

        zipf.write(modified_rtconfig_path, arcname=os.path.join(os.path.basename(data_path), rtconfig_path))

    if theme_name == master_theme:
        create_master_theme(zip_file_path)

    os.remove(modified_rtconfig_path)

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

        create_zip(theme_file, ui_img_path, config["FM"])