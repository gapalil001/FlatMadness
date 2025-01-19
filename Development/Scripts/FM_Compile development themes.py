import os
import zipfile
import configparser

from reaper_python import *

root_path = RPR_GetExtState("fm4_adjuster", "py_root_path")
resources_path = os.path.join(RPR_GetResourcePath(), "ColorThemes")
rtconfig_path = 'rtconfig.txt'
something_changed = False
rtconfig_content = None

def log(msg):
    RPR_ShowConsoleMsg(str(msg) + "\n")

def is_correct_root_path(path):
    return os.path.exists(os.path.join(path, "Scripts", "FM_Compile development themes.py"))

def get_theme_path(prefix):
    return os.path.join(resources_path, f"[DEV] Flat Madness {prefix}.ReaperThemeZip")

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

def create_zip(theme_file, data_path, theme_rtconfig_path):
    theme_name = os.path.splitext(theme_file)[0]
    reaper_theme_path = get_theme_path(theme_name)

    log(f"Compiling \"{os.path.basename(reaper_theme_path)}\"...")

    with zipfile.ZipFile(reaper_theme_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(os.path.join(root_path, "Themes", theme_file), arcname=theme_file)

        for root, _, files in os.walk(ui_img_path):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, start=data_path)
                zipf.write(file_path, arcname=os.path.join(os.path.basename(data_path), arcname))

        zipf.write(theme_rtconfig_path, arcname=os.path.join(os.path.basename(data_path), rtconfig_path))

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

            if should_create_zip(theme_file, ui_img_path):
                modified_rtconfig_path = create_rtconfig_for_theme(config["FM"])
                create_zip(theme_file, ui_img_path, modified_rtconfig_path)
                something_changed = True

                os.remove(modified_rtconfig_path)

    if something_changed:
        RPR_OpenColorThemeFile(RPR_GetLastColorThemeFile())
    else:
        log(f"No any changes.")
else:
    RPR_MB("Root path to Development folder is not set. Please execute script again and specify correct path.", "Root path set", 0)