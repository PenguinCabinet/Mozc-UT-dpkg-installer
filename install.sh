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

dirs=(*/)
mozc_dir=${dirs[0]%/}

git clone --depth 1 https://github.com/utuhiro78/merge-ut-dictionaries.git
cd merge-ut-dictionaries/src/merge/
sh make.sh
cat mozcdic-ut.txt >> ../../../$(mozc_dir)/src/data/dictionary_oss/dictionary00.txt

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

sudo apt install --reinstall ./common/*.deb -y

sudo apt install --reinstall ./$1/*.deb -y


