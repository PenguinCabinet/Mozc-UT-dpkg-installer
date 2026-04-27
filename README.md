# mozc-ut-dpkg-installer
dpkg環境で[mozc-ut](https://utuhiro78.github.io/linuxplayers/mozc-ut.html)をワンライナーでインストールするためのシェルスクリプトです。

このリポジトリには、インストール手順が記されているだけで、Mozc UT Dictionariesの辞書データ等は一切含まれていません。

## 使い方
第一引数はIM Frameworkを指定してください。選択肢は、`ibus|fcitx|fcitx5|uim|emacs`です。今回の例では`ibus`を指定しています。apt-srcのダウンロード、辞書データの適用、dpkgによるインストールが最後まで行われます。
```
curl -s https://raw.githubusercontent.com/PenguinCabinet/Mozc-UT-dpkg-installer/refs/heads/main/install.sh | bash -s -- ibus
```

`mozc-ut`にソースコードや辞書データ、dpkgなどが生成されます。`mozc-ut/dpkg`にIM Frameworkごとにディレクトリが分けられて保存されています。
```
% tree mozc-ut/dpkg/
mozc-ut/dpkg
├── common
│   ├── mozc-data_2.29.5160.102+dfsg-1.4_all.deb
│   ├── mozc-server-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   ├── mozc-server_2.29.5160.102+dfsg-1.4_amd64.deb
│   ├── mozc-utils-gui-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   └── mozc-utils-gui_2.29.5160.102+dfsg-1.4_amd64.deb
├── emacs
│   ├── emacs-mozc-bin-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   ├── emacs-mozc-bin_2.29.5160.102+dfsg-1.4_amd64.deb
│   └── emacs-mozc_2.29.5160.102+dfsg-1.4_amd64.deb
├── fcitx
│   ├── fcitx-mozc-data_2.29.5160.102+dfsg-1.4_all.deb
│   ├── fcitx-mozc-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   └── fcitx-mozc_2.29.5160.102+dfsg-1.4_amd64.deb
├── fcitx5
│   ├── fcitx5-mozc-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   └── fcitx5-mozc_2.29.5160.102+dfsg-1.4_amd64.deb
├── ibus
│   ├── ibus-mozc-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
│   └── ibus-mozc_2.29.5160.102+dfsg-1.4_amd64.deb
└── uim
    ├── uim-mozc-dbgsym_2.29.5160.102+dfsg-1.4_amd64.deb
    └── uim-mozc_2.29.5160.102+dfsg-1.4_amd64.deb

7 directories, 17 files
```





