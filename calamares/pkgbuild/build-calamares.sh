#!/bin/bash

set -e

PKG_DIR="/etc/calamares/pkgbuild"
PKGBUILD="$PKG_DIR/PKGBUILD"

# Format current date as YY.MM.DD (e.g., 25.05.22)
DATE_VER=$(date +%y.%m.%d)
NEW_PKGREL="01"

# Ensure PKGBUILD exists
if [[ ! -f "$PKGBUILD" ]]; then
    echo "Error: PKGBUILD not found at $PKGBUILD"
    exit 1
fi

echo "Updating pkgver to $DATE_VER and pkgrel to $NEW_PKGREL..."

# Use sed to update pkgver and pkgrel in the PKGBUILD
sed -i -E "s/^pkgver=.*/pkgver=$DATE_VER/" "$PKGBUILD"
sed -i -E "s/^pkgrel=.*/pkgrel=$NEW_PKGREL/" "$PKGBUILD"

# Recompute prepare() path replacements if needed (not done here explicitly)

# Change to package directory
cd "$PKG_DIR"

# Build package
echo "Building the package..."
makepkg -fsi --noconfirm

echo "Calamares built and installed successfully."
