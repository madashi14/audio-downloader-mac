#!/bin/bash
# Doppio clic per installare (o aggiornare) Audio Downloader su questo Mac.
cd "$(dirname "$0")" || exit 1
bash installer/installa.sh
echo
read -n 1 -s -r -p "Premi un tasto per chiudere questa finestra…"
echo
