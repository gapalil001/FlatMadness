import os
import zipfile
import configparser
import json

from reaper_python import *

root_path = "/Users/monolok/Developer/Reaper/FlatMadness/Development"
resources_path = os.path.join(RPR_GetResourcePath(), "ColorThemes")
rtconfig_path = 'rtconfig.txt'
config_json_path = 'config.json'

def log(msg):
    RPR_ShowConsoleMsg(str(msg) + "\n")

def get_theme_path(prefix):
    return os.path.join(resources_path, f"Flat Madness {prefix} Dev.ReaperThemeZip")

with open(os.path.join(root_path, config_json_path), "r") as file:
    json_config = json.load(file)

def should_create_zip(theme_file, data_path):
    theme_name = os.path.splitext(theme_file)[0]
    reaper_theme_path = get_theme_path(theme_name)

    if not os.path.exists(reaper_theme_path):
        return True

    reaper_theme_creation_time = os.path.getmtime(reaper_theme_path)

    if os.path.getmtime(os.path.join(root_path, 'rtconfig.txt')) > reaper_theme_creation_time:
        return True

    if os.path.getmtime(os.path.join(root_path, "Themes", theme_file)) > reaper_theme_creation_time:
        return True

    for root, _, files in os.walk(os.path.join(root_path, "Data", data_path)):
        for file in files:
            file_path = os.path.join(root, file)
            file_mod_time = os.path.getmtime(file_path)
            if file_mod_time > reaper_theme_creation_time:
                return True

    return False

def create_zip(theme_file, data_path):
    theme_name = os.path.splitext(theme_file)[0]
    reaper_theme_path = get_theme_path(theme_name)

    log(f"Compiling \"{os.path.basename(reaper_theme_path)}\"...")

    with open(os.path.join(root_path, rtconfig_path), "r", encoding="utf-8") as rtconfig_file:
        rtconfig_content = rtconfig_file.read()

    for key, value in json_config.items():
        if isinstance(value, list):
            rtconfig_content = rtconfig_content.replace("{" + key + "}",
                                                        str(value[0] if "Bright" in data_path else value[1]))
        else:
            rtconfig_content = rtconfig_content.replace("{" + key + "}", str(value))

    modified_rtconfig_path = os.path.join(root_path, "rtconfig_temp.txt")
    with open(modified_rtconfig_path, "w", encoding="utf-8") as modified_rtconfig_file:
        modified_rtconfig_file.write(rtconfig_content)

    with zipfile.ZipFile(reaper_theme_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(os.path.join(root_path, "Themes", theme_file), arcname=theme_file)

        for root, _, files in os.walk(ui_img_path):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, start=data_path)
                zipf.write(file_path, arcname=os.path.join(os.path.basename(data_path), arcname))

        zipf.write(modified_rtconfig_path, arcname=os.path.join(os.path.basename(data_path), rtconfig_path))

    os.remove(modified_rtconfig_path)


something_changed = False

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

        if should_create_zip(theme_file, ui_img_path):
            create_zip(theme_file, ui_img_path)
            something_changed = True

if something_changed:
    RPR_OpenColorThemeFile(RPR_GetLastColorThemeFile())
else:
    log(f"No any changes.")