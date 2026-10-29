#!bin/bash

set -euo pipefail

CONTAINER_NAME="labview-env"
CONTAINER_IMAGE="docker.io/library/ubuntu:24.04"
CONTAINER_HOME="LabVIEW_Ubuntu_2404_Home"


setup_inside_container(){
    echo "[*] Starting configuration inside the container..."

    # Install base tools
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y ca-certificates \
        curl \
        wget \
        gnupg \
        xdg-utils \
        desktop-file-utils

    # Install graphics dependencies
    sudo apt install -y --no-install-recommends \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libxtst6 \
        libxi6 \
        libgl1 \
        libgl1-mesa-dri \
        libglu1-mesa \
        libxrandr2 \
        libxinerama1 \
        libxcursor1 \
        libfontconfig1 \
        libfreetype6 
    
    # Check for labview community repository file in the home directory
    if ! ls "$HOME"| grep -Ei "ni-labview-.+-community_.+.deb"; then
        echo "No LabVIEW community repository package file in the home directory."
        echo "Download the zip file from the National Instruments website and extract the DEB package in the home directory of the container"
        exit 1
    fi

    NI_DEB_PACK=$(ls "$HOME" | grep -Ei "ni-labview-.+-community_.+.deb")
    echo $NI_DEB_PACK
    LABVIEW_PACKAGE="${NI_DEB_PACK%%_*}"
    echo $LABVIEW_PACKAGE
    sudo apt install "$HOME/$NI_DEB_PACK" -y
    sudo apt update
    sudo apt install $LABVIEW_PACKAGE -y

    # Install Firefox official repository (DEB Firefox)
    echo "[*] Configuring Mozilla APT repository"
    sudo install -d -m 0755 /etc/apt/keyrings
    if [ ! -f  /etc/apt/keyrings/packages.mozilla.org.asc ]; then
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
    fi

    gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'

    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null

    echo 'Package: *
    Pin: origin packages.mozilla.org
    Pin-Priority: 1000' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

    echo 'Package: firefox
    Pin: release o=Ubuntu
    Pin-Priority: -1' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

    sudo apt purge -y firefox snapd 2>/dev/null || true
    sudo apt update
    sudo apt install firefox

    # Create wrapper xdg-open in ~/.local/bin
    echo "[*]Configure xdg-open wrapper..."
    mkdir -p "$HOME/.local/bin"
    cat << 'EOF' > "$HOME/.local/bin/xdg-open"
#!/usr/bin/env bash
# Decouple from KDE/Plasma host 
unset XDG_CURRENT_DESKTOP
unset KDE_SESSION_VERSION

# Execute Firefox in the background
/usr/bin/firefox "$@" >/dev/null 2>&1 &
exit 0
EOF

    chmod +x "$HOME/.local/bin/xdg-open"

    if ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi

    # Create desktop entry for LabVIEW
    echo "[*] Generating .desktop file..."
    mkdir -p "$HOME/.local/share/applications"

    WHICH_LV="$(command -v labview64 || command -v Labview64 || echo "")"
    if [ -z "$WHICH_LV" ]; then
        if [ -x "/usr/local/natinst/labview/labview64" ]; then
            WHICH_LV="/usr/local/natinst/labview/labview64"
        elif [ -x "/usr/local/bin/labview64" ]; then
            WHICH_LV="/usr/local/bin/labview64"
        fi
    fi

    # Find Icon
    ICON_PATH="$(find /usr/local/natinst /usr/share/icons -iname "*labview*.png" 2>/dev/null | head -n 1 || true)"
    [ -z "$ICON_PATH" ] && ICON_PATH="applications-development"

    if [ -n "$WHICH_LV" ]; then
        cat << EOF > "$HOME/.local/share/applications/labview64.desktop"
[Desktop Entry]
Type=Application
Name=LabVIEW 2026 64-bit
Comment=National Instruments LabVIEW Community Edition
Exec=env PATH="$HOME/.local/bin:\$PATH" $WHICH_LV %U
Icon=$ICON_PATH
Terminal=false
Categories=Development;Engineering;
StartupNotify=true
EOF
        chmod +x "$HOME/.local/share/applications/labview64.desktop"
        echo "[*] Desktop entry creata in $HOME/.local/share/applications/labview64.desktop"

        # 6. Export app to the host system
        if command -v distrobox-export >/dev/null 2>&1; then
            echo "[*] Esportazione lanciatore verso l'host via distrobox-export..."
            distrobox-export --app labview64
        fi
    else
        echo "[!] ATTENZIONE: Binario LabVIEW non ancora rilevato."
        echo "    Installa i pacchetti .deb di LabVIEW nel container, poi rilancia lo script o esegui:"
        echo "    distrobox-export --app labview64"
    fi

    echo "[OK] Configurazione interna completata con successo."
}

main(){
    if [ -f "/run/.containerenv" ] || [ -f "/.dockerenv" ]; then
        # setup
        exit 0
    fi

    echo "Esecuzione rilevata su Host"

    # Verify dependencies

    # command -v tool -> exit code 0 (true) if installed
    #                 -> exit code != 0 (false) if not installed


    if ! command -v podman > /dev/null 2>&1 && ! command -v docker > /dev/null 2>&1; then
        echo "[-] Nessun container rilevato. Installa Podman o Docker."
        exit 1
    fi

    if ! command -v distrobox > /dev/null 2>&1; then
        echo "[-] Distrobox not found. Install Distrobox first"
        exit 1
    fi

    # Create container if it doesn't exist
    if ! distrobox list | grep -qw "$CONTAINER_NAME"; then
        echo "[*] Creating Distrobox container: $CONTAINER_NAME ($CONTAINER_IMAGE)..."
        mkdir -p "$HOME/Distrobox_Containers/$CONTAINER_HOME"
        distrobox create --name "$CONTAINER_NAME" --image "$CONTAINER_IMAGE" --home "$HOME/Distrobox_Containers/$CONTAINER_HOME" --yes
    else
        echo "[*] Container $CONTAINER_NAME already exists"
    fi

    # Execute script inside the container
    echo "[*] Accessing the container and executing provisioning..."
    distrobox enter "$CONTAINER_NAME" -- bash -c "$(declare -f setup_inside_container); setup_inside_container"

    echo ""
    echo "[OK] Setup completed!"
    echo "To enter the container execute:"
    echo "distrobox enter $CONTAINER_NAME"
    echo ""

}

main "$@"