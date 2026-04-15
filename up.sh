#!/bin/bash
set -eo pipefail
##################################################################################################################
# Author    : Erik Dubois
# Website   : https://www.erikdubois.be
# Youtube   : https://youtube.com/erikdubois
# Github    : https://github.com/erikdubois
# Github    : https://github.com/kirodubes
# Github    : https://github.com/buildra
# SF        : https://sourceforge.net/projects/kiro/files/
##################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue
##################################################################################################################

echo "Remember to change the pkgbuild for calamares if needed"

sleep 3

# variables and functions
workdir=$(pwd)
dir="calamares-3.3.14.r132.g841b478-3"
source="/home/erik/KIRO/kiro-pkgbuild/"
destiny="/home/erik/KIRO/kiro-calamares-config/etc/calamares/pkgbuild/"

# Function to compare package versions
compare_versions() {
    local pkg_name=$1
    local packages_dir=$2

    # Get latest version from pacman repo
    latest_version=$(pacman -Si "$pkg_name" 2>/dev/null | grep "^Version" | awk '{print $3}')

    if [ -z "$latest_version" ]; then
        echo "Could not determine latest version for $pkg_name"
        return 1
    fi

    # Find existing package file
    existing_file=$(ls "$packages_dir"/"$pkg_name"-*.pkg.tar.zst 2>/dev/null | head -1)

    if [ -z "$existing_file" ]; then
        # No existing file, download is needed
        return 0
    fi

    # Extract version from existing filename (format: name-version-release-arch.pkg.tar.zst)
    existing_version=$(basename "$existing_file" | sed "s/^$pkg_name-//;s/-[^-]*-[^-]*\.pkg\.tar\.zst$//" | sed 's/-[0-9]*$//')

    # Compare versions using vercmp
    result=$(vercmp "$latest_version" "$existing_version" 2>/dev/null || echo "0")

    if [ "$result" -gt 0 ]; then
        # New version is newer, download needed
        echo "$pkg_name: newer version available ($existing_version → $latest_version)"
        return 0
    else
        # Current version is up to date
        echo "$pkg_name: already up to date ($existing_version)"
        return 1
    fi
}

##################################################################################################################

if [ -d "$destiny" ]; then
    rm -rf "$destiny"
fi

if ! [ -d "$destiny" ]; then
    mkdir "$destiny"
fi

cp -r $source$dir/* $destiny

##################################################################################################################
# Download ucode packages to /etc/calamares/packages
##################################################################################################################

echo "Checking ucode packages..."

packages_dir="etc/calamares/packages"

# Create packages directory if it doesn't exist
if ! [ -d "$packages_dir" ]; then
    mkdir -p "$packages_dir"
fi

# Check and download packages if newer versions are available
packages_to_download=""

for pkg in intel-ucode amd-ucode; do
    if compare_versions "$pkg" "$packages_dir"; then
        packages_to_download="$packages_to_download $pkg"
    fi
done

if [ -n "$packages_to_download" ]; then
    echo "Downloading newer versions:$packages_to_download"
    sudo pacman -Sw --cachedir "$packages_dir" --noconfirm $packages_to_download
    echo "Packages downloaded to $packages_dir"
else
    echo "All packages are up to date. Keeping existing files."
fi

##################################################################################################################

# Below command will backup everything inside the project folder
git add --all .

# Committing to the local repository with a message containing the time details and commit text

git commit -m "update"

# Push the local files to github

branch=$(git rev-parse --abbrev-ref HEAD)
git push -u origin "$branch"

echo
tput setaf 6
echo "##############################################################"
echo "###################  $(basename $0) done"
echo "##############################################################"
tput sgr0
echo
