#!/bin/bash
# Installa (o aggiorna) Audio Downloader su macOS.
#
# Non serve la password di amministratore e non tocca il resto del Mac:
# Python, ffmpeg, Deno e l'app finiscono in
#     ~/Library/Application Support/AudioDownloader
# e l'icona "Audio Downloader" viene messa in Applicazioni.
#
# Uso:  bash installa.sh                                (dalla cartella scaricata)
#       curl -fsSL <link-raw>/installer/installa.sh | bash   (direttamente da GitHub)
#
# Variabili utili per i test: AUDIODL_NON_APRIRE=1 (non apre l'app alla fine)

# Tutto dentro una funzione: con "curl | bash" lo script viene letto per intero
# prima di partire, quindi un download interrotto non esegue mezzo installer.
main() {
    set -euo pipefail

    REPO="madashi14/audio-downloader-mac"
    BRANCH="main"
    NOME_APP="Audio Downloader"
    DEST="$HOME/Library/Application Support/AudioDownloader"
    ENV_DIR="$DEST/env"
    APP_FILES="$DEST/app"
    MAMBA="$DEST/bin/micromamba"
    export MAMBA_ROOT_PREFIX="$DEST/mamba"
    TMP_SORGENTE=""

    titolo() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
    errore() { printf '\n\033[1;31mErrore:\033[0m %s\n' "$1" >&2; exit 1; }
    pulizia() { if [ -n "$TMP_SORGENTE" ]; then rm -rf "$TMP_SORGENTE"; fi; }
    trap pulizia EXIT
    trap 'errore "installazione interrotta (riga $LINENO). Controlla la connessione e riprova; se il problema resta, manda uno screenshot di questa finestra."' ERR

    [ "$(uname -s)" = "Darwin" ] || errore "questo installer funziona solo su macOS."
    # processore reale (anche se il Terminale gira sotto Rosetta)
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then
        PIATTAFORMA="osx-arm64"; ARCH_CMD="arch -arm64"
    else
        PIATTAFORMA="osx-64"; ARCH_CMD=""
    fi

    printf '\n\033[1m♫  Installazione di %s\033[0m\n' "$NOME_APP"
    echo "Ci vorranno alcuni minuti (scarica circa 300 MB). Non serve la password."

    # ------------------------------------------------------------------ 1
    titolo "1/5  Preparo i file dell'app"
    QUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
    if [ -n "$QUI" ] && [ -f "$QUI/../app/gui.py" ]; then
        SORGENTE="$(cd "$QUI/.." && pwd)"
        echo "Uso i file della cartella: $SORGENTE"
    else
        TMP_SORGENTE="$(mktemp -d)"
        curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
            | tar -xz -C "$TMP_SORGENTE" --strip-components 1
        SORGENTE="$TMP_SORGENTE"
        echo "Scaricati da github.com/$REPO"
    fi

    # ------------------------------------------------------------------ 2
    titolo "2/5  Scarico micromamba (gestisce Python e ffmpeg)"
    mkdir -p "$DEST/bin"
    if [ ! -x "$MAMBA" ]; then
        curl -fsSL -o "$MAMBA.tmp" \
            "https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-$PIATTAFORMA"
        chmod +x "$MAMBA.tmp"
        mv "$MAMBA.tmp" "$MAMBA"
    fi
    echo "micromamba $("$MAMBA" --version)"

    # ------------------------------------------------------------------ 3
    titolo "3/5  Installo Python, ffmpeg e le librerie (è la parte più lunga)"
    PACCHETTI="python=3.12 tk ffmpeg pip"
    if [ -d "$ENV_DIR/conda-meta" ]; then
        $ARCH_CMD "$MAMBA" install -y -p "$ENV_DIR" -c conda-forge --override-channels $PACCHETTI </dev/null
    else
        $ARCH_CMD "$MAMBA" create -y -p "$ENV_DIR" -c conda-forge --override-channels $PACCHETTI </dev/null
    fi
    echo "Installo yt-dlp, Deno e l'interfaccia grafica…"
    $ARCH_CMD "$ENV_DIR/bin/python" -m pip install --quiet --disable-pip-version-check --no-cache-dir --upgrade \
        "yt-dlp[default]" customtkinter pillow deno pyobjc-framework-Cocoa </dev/null
    # i pacchetti scaricati non servono più: liberano parecchio spazio
    "$MAMBA" clean --all --yes >/dev/null 2>&1 || true

    # controlli: se qualcosa manca meglio dirlo adesso che al primo download
    "$ENV_DIR/bin/python" -c "import tkinter, customtkinter, yt_dlp, PIL" \
        || errore "le librerie Python non si sono installate correttamente."
    # (grep senza -q: con pipefail, -q chiude la pipe in anticipo e fa "fallire" ffmpeg)
    "$ENV_DIR/bin/ffmpeg" -hide_banner -encoders 2>/dev/null | grep libmp3lame >/dev/null \
        || errore "ffmpeg non supporta la conversione in MP3."
    "$ENV_DIR/bin/deno" --version >/dev/null 2>&1 \
        || errore "Deno non si è installato correttamente."

    # ------------------------------------------------------------------ 4
    titolo "4/5  Copio l'app"
    rm -rf "$APP_FILES"
    mkdir -p "$APP_FILES"
    cp -R "$SORGENTE/app/." "$APP_FILES/"
    cp "$SORGENTE/installer/disinstalla.sh" "$DEST/disinstalla.sh"
    chmod +x "$DEST/disinstalla.sh"

    # ------------------------------------------------------------------ 5
    titolo "5/5  Creo l'app in Applicazioni"
    if [ -w /Applications ]; then
        CARTELLA_APP="/Applications"
    else
        CARTELLA_APP="$HOME/Applications"
        mkdir -p "$CARTELLA_APP"
    fi
    "$ENV_DIR/bin/python" "$SORGENTE/installer/crea_app_mac.py" \
        --env "$ENV_DIR" --app-files "$APP_FILES" --log "$DEST/avvio.log" \
        --dest "$CARTELLA_APP/$NOME_APP.app"

    printf '\n\033[1;32m✓ Fatto!\033[0m "%s" è in %s.\n' "$NOME_APP" "$CARTELLA_APP"
    echo "La trovi anche con Spotlight (⌘ + spazio, scrivi \"Audio\")."
    echo "Per aggiornarla rilancia questo installer; per toglierla: bash \"$DEST/disinstalla.sh\""
    if [ -z "${AUDIODL_NON_APRIRE:-}" ]; then
        open "$CARTELLA_APP/$NOME_APP.app"
    fi
}

main "$@"
