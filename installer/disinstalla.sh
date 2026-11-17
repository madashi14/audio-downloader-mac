#!/bin/bash
# Rimuove Audio Downloader dal Mac: l'app in Applicazioni e la cartella con Python,
# ffmpeg, Deno, impostazioni e cronologia. Gli MP3 scaricati NON vengono toccati.
set -uo pipefail

NOME_APP="Audio Downloader"
DEST="$HOME/Library/Application Support/AudioDownloader"

pkill -f "AudioDownloader/app/gui.py" 2>/dev/null || true
for cartella in "/Applications" "$HOME/Applications"; do
    if [ -d "$cartella/$NOME_APP.app" ]; then
        rm -rf "$cartella/$NOME_APP.app" && echo "Rimossa $cartella/$NOME_APP.app"
    fi
done
if [ -d "$DEST" ]; then
    rm -rf "$DEST" && echo "Rimossa $DEST"
fi
printf '\n\033[1;32m✓ Audio Downloader è stato disinstallato.\033[0m I tuoi MP3 sono rimasti dove li avevi salvati.\n'
