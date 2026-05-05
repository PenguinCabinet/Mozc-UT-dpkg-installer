#!/bin/bash
set -euo pipefail

# Ensure we are in the project root
cd "$(dirname "$0")"

# Create a working directory
mkdir -p mozc-ut
cd mozc-ut

sudo apt update
sudo apt install git wget apt-src devscripts build-essential -y 

# Check input and install source
if [[ "$1" =~ ^(ibus|fcitx|fcitx5|emacs|uim)$ ]]; then
    echo "Installing source for $1-mozc..."
    apt-src install "$1-mozc"
    sudo apt-get build-dep "$1-mozc" -y
else
    echo "Usage: $0 {ibus|fcitx|fcitx5|emacs|uim}"
    exit 1
fi

# Find the source directory
mozc_dir=$(ls -d */ | grep mozc | head -n 1 | sed 's:/$::')

# Clone and build UT dictionary
if [ ! -d "merge-ut-dictionaries" ]; then
    git clone --depth 1 https://github.com/utuhiro78/merge-ut-dictionaries.git
fi
cd merge-ut-dictionaries/src/merge/
bash make.sh

# Apply patch to dictionary00.txt if not already applied
DICT_FILE="../../../${mozc_dir}/src/data/dictionary_oss/dictionary00.txt"
# Check if the first line of UT dictionary is already in dictionary00.txt
FIRST_LINE=$(head -n 1 mozcdic-ut.txt)
if ! grep -qF "$FIRST_LINE" "$DICT_FILE" 2>/dev/null; then
    echo "Applying UT dictionary patch..."
    cat mozcdic-ut.txt >> "$DICT_FILE"
else
    echo "UT dictionary patch already applied."
fi

# Build the packages
echo "Building packages in ${mozc_dir}..."
cd "../../../${mozc_dir}"

# Fix debian/rules to be sequential and avoid source poisoning
# This prevents linker errors (relocation R_X86_64_TPOFF32) when building shared objects
sed -i 's/override_dh_auto_build: build_dynamic_link build_static_link/override_dh_auto_build:\n\t$(MAKE) -f debian\/rules build_dynamic_link\n\t$(MAKE) -f debian\/rules build_static_link/' debian/rules

# Revert poisoned protobuf.gyp if it was modified in a previous attempt
if [ -f "src/protobuf/protobuf.gyp" ]; then
    sed -i "s|'/usr/lib/[^']*/libprotobuf\.a -latomic -latomic'|'-lprotobuf'|g" src/protobuf/protobuf.gyp
    sed -i "s|'/usr/lib/[^']*/libprotobuf\.a -latomic'|'-lprotobuf'|g" src/protobuf/protobuf.gyp
fi

# Add a local version suffix so it's recognized as an update
if [[ ! $(head -n 1 debian/changelog) =~ \+ut1 ]]; then
    export DEBEMAIL="user@example.com"
    export DEBFULLNAME="User"
    dch -l "+ut1" "Applied mozc-ut patch"
fi

# Use -b to build binary packages only, -uc -us to skip signing
dpkg-buildpackage -b -uc -us

# Move packages to a dedicated directory
cd ..
mkdir -p dpkg
mv *.deb dpkg/ 2>/dev/null || true
cd dpkg

# Install the built packages
echo "Installing packages..."
sudo dpkg -i mozc-server_*.deb mozc-data_*.deb mozc-utils-gui_*.deb ./*"$1"*.deb || sudo apt-get install -f -y

# Restart Mozc server to apply changes
echo "Restarting mozc_server..."
killall mozc_server || true

echo "--------------------------------------------------"
echo "Installation complete."
echo "Please restart your Input Method (ibus/fcitx) or relogin to apply changes."
echo "You can verify the dictionary by typing words included in mozc-ut."
echo "--------------------------------------------------"
