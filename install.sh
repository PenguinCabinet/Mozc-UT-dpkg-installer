#!/bin/bash
set -euo pipefail

mkdir mozc-ut
cd mozc-ut

sudo apt install git wget apt-src -y 

if [[ "$1" == "ibus" ]]; then
	apt-src install ibus-mozc
elif [[ "$1" == "fcitx" ]]; then
	apt-src install fcitx-mozc
elif [[ "$1" == "fcitx5" ]]; then
	apt-src install fcitx5-mozc
elif [[ "$1" == "emacs" ]]; then
	apt-src install emacs-mozc
elif [[ "$1" == "uim" ]]; then
	apt-src install uim-mozc
else
	echo "The IM Framework does not exist."
	exit
fi

mozc_dir=$(ls -d */|grep mozc| sed 's:/$::')

git clone --depth 1 https://github.com/utuhiro78/merge-ut-dictionaries.git
cd merge-ut-dictionaries/src/merge/
bash make.sh
cat mozcdic-ut.txt >> ../../../${mozc_dir}/src/data/dictionary_oss/dictionary00.txt

echo "$mozc_dir"
ls ../../../${mozc_dir}/src/data/dictionary_oss/

cd ../../../
apt-src build $1-mozc

mkdir dpkg
mv *.deb dpkg
cd dpkg

mkdir uim ibus fcitx fcitx5 emacs common

mv *uim*.deb uim
mv *ibus*.deb ibus
mv *fcitx5*.deb fcitx5
mv *fcitx*.deb fcitx
mv *emacs*.deb emacs
mv *.deb common

for file in ./common/*; do
  sudo apt-get install --reinstall $file -y
done

for file in ./$1/*; do
  sudo apt-get install --reinstall $file -y
done

tree

sudo apt-get install --reinstall ./common/*.deb -y
sudo apt-get install --reinstall ./$1/*.deb -y

sudo dpkg -i ./common/*.deb
sudo dpkg -i ./$1/*.deb


