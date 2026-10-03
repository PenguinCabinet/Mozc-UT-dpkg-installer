#!/bin/bash
# Mozc UT dictionaries (https://github.com/utuhiro78/merge-ut-dictionaries) を
# dpkg ビルド済み Mozc に適用してインストールする。
# 使い方: ./install.sh {ibus|fcitx|fcitx5|emacs|uim}
set -euo pipefail

readonly WORK_DIR="mozc-ut"
readonly UT_REPO="https://github.com/utuhiro78/merge-ut-dictionaries.git"

IM=""
MOZC_DIR=""
WORK_ABS=""

usage() {
    echo "Usage: $0 {ibus|fcitx|fcitx5|emacs|uim}"
    exit 1
}

parse_args() {
    if [[ $# -ne 1 || ! "$1" =~ ^(ibus|fcitx|fcitx5|emacs|uim)$ ]]; then
        usage
    fi
    IM="$1"
}

install_dependencies() {
    sudo apt update
    sudo apt install git apt-src devscripts build-essential python3 -y
}

fetch_mozc_source() {
    echo "Installing source for ${IM}-mozc..."
    apt-src install "${IM}-mozc"
    sudo apt-get build-dep "${IM}-mozc" -y
}

find_mozc_dir() {
    MOZC_DIR=$(ls -d */ | grep mozc | head -n 1 | sed 's:/$::')
}

prepare_ut_dictionary() {
    if [ ! -d "merge-ut-dictionaries" ]; then
        git clone --depth 1 "$UT_REPO"
    fi
    # make.sh は `python` を呼ぶが、python バイナリの無い環境
    # (Debian trixie 以降など) がある。python-is-python3 に依存せず、
    # 実体の python3 へ読み替える。再実行時は既に置換済みなので no-op。
    sed -i 's/^python /python3 /' merge-ut-dictionaries/src/merge/make.sh
    ( cd merge-ut-dictionaries/src/merge/ && bash make.sh )
}

apply_ut_patch() {
    local dict_file="${WORK_ABS}/${MOZC_DIR}/src/data/dictionary_oss/dictionary00.txt"
    local ut_dict="${WORK_ABS}/merge-ut-dictionaries/src/merge/mozcdic-ut.txt"
    # Check if the first line of UT dictionary is already in dictionary00.txt
    local first_line
    first_line=$(head -n 1 "$ut_dict")
    if ! grep -qF "$first_line" "$dict_file" 2>/dev/null; then
        echo "Applying UT dictionary patch..."
        cat "$ut_dict" >> "$dict_file"
    else
        echo "UT dictionary patch already applied."
    fi
}

build_packages() {
    echo "Building packages in ${MOZC_DIR}..."
    cd "${WORK_ABS}/${MOZC_DIR}"

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
    sudo dpkg -i mozc-server_*.deb mozc-data_*.deb mozc-utils-gui_*.deb ./*"${IM}"*.deb || sudo apt-get install -f -y

    # Restart Mozc server to apply changes
    echo "Restarting mozc_server..."
    killall mozc_server || true

    echo "--------------------------------------------------"
    echo "Installation complete."
    echo "Please restart your Input Method (ibus/fcitx) or relogin to apply changes."
    echo "You can verify the dictionary by typing words included in mozc-ut."
    echo "--------------------------------------------------"
}

main() {
    parse_args "$@"

    # Ensure we are in the project root
    cd "$(dirname "$0")"

    # Create a working directory
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    WORK_ABS="$(pwd)"

    install_dependencies
    fetch_mozc_source
    find_mozc_dir
    prepare_ut_dictionary
    apply_ut_patch
    build_packages
}

main "$@"
