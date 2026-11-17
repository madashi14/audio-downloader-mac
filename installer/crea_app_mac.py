"""Crea "Audio Downloader.app": un'app vera da Applicazioni/Dock/Spotlight che avvia la GUI.

Lo lancia installa.sh con il Python appena installato; non va eseguito a mano.
"""
import argparse
import os
import plistlib
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

NOME_ESEGUIBILE = "AudioDownloader"
LSREGISTER = ("/System/Library/Frameworks/CoreServices.framework/Frameworks/"
              "LaunchServices.framework/Support/lsregister")


def crea_icns(png, destinazione):
    """Converte icon.png (1024 px) in icon.icns; prima con Pillow, poi con iconutil."""
    img = Image.open(png).convert("RGBA")
    try:
        img.save(destinazione, format="ICNS")
        return
    except Exception:
        pass
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "icon.iconset"
        iconset.mkdir()
        for lato in (16, 32, 128, 256, 512):
            img.resize((lato, lato), Image.LANCZOS).save(iconset / f"icon_{lato}x{lato}.png")
            img.resize((lato * 2, lato * 2), Image.LANCZOS).save(iconset / f"icon_{lato}x{lato}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(destinazione)], check=True)


def crea_app(env_dir, app_files, dest, log):
    dest = Path(dest)
    if dest.exists():
        shutil.rmtree(dest)
    contents = dest / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir()

    python = Path(env_dir) / "bin" / "python"
    gui = Path(app_files) / "gui.py"
    q = shlex.quote
    launcher = contents / "MacOS" / NOME_ESEGUIBILE
    launcher.write_text(
        "#!/bin/bash\n"
        "# Avvia Audio Downloader con il Python installato dall'installer.\n"
        "# Le app aperte dal Finder non ricevono il PATH del Terminale: lo impostiamo qui.\n"
        f"export PATH={q(str(Path(env_dir) / 'bin'))}:\"$PATH\"\n"
        f"cd {q(str(app_files))} || exit 1\n"
        f"exec {q(str(python))} {q(str(gui))} >>{q(str(log))} 2>&1\n",
        encoding="utf-8",
    )
    launcher.chmod(0o755)

    with open(contents / "Info.plist", "wb") as f:
        plistlib.dump({
            "CFBundleName": "Audio Downloader",
            "CFBundleDisplayName": "Audio Downloader",
            "CFBundleIdentifier": "app.audiodownloader.mac",
            "CFBundleVersion": "1.0",
            "CFBundleShortVersionString": "1.0",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": NOME_ESEGUIBILE,
            "CFBundleIconFile": "icon",
            "LSMinimumSystemVersion": "11.0",
            "LSApplicationCategoryType": "public.app-category.music",
            "NSHighResolutionCapable": True,
        }, f)
    (contents / "PkgInfo").write_text("APPL????", encoding="ascii")

    crea_icns(Path(app_files) / "assets" / "icon.png", contents / "Resources" / "icon.icns")

    # aggiorna la cache di Finder/Launchpad così l'icona compare subito
    os.utime(dest, None)
    if Path(LSREGISTER).exists():
        subprocess.run([LSREGISTER, "-f", str(dest)], check=False)
    print("App creata:", dest)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--env", required=True)
    p.add_argument("--app-files", required=True)
    p.add_argument("--dest", required=True)
    p.add_argument("--log", required=True)
    a = p.parse_args()
    crea_app(a.env, a.app_files, a.dest, a.log)
