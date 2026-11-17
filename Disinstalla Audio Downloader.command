#!/bin/bash
# Doppio clic per togliere Audio Downloader da questo Mac (gli MP3 scaricati restano).
cd "$(dirname "$0")" || exit 1
read -r -p "Vuoi davvero disinstallare Audio Downloader? (s/n) " risposta
case "$risposta" in
    s|S|si|sì|Si|Sì) bash installer/disinstalla.sh ;;
    *) echo "Ok, non ho tolto niente." ;;
esac
echo
read -n 1 -s -r -p "Premi un tasto per chiudere questa finestra…"
echo
