# mozc-ut-dpkg-installer
dpkg環境において[Mozc UT Dictionaries](https://utuhiro78.github.io/linuxplayers/mozc-ut.html)をワンライナーでインストールするスクリプトです。

このリポジトリには、インストール手順が記されているだけで、Mozc UT Dictionariesの辞書データ等は一切含まれていません。

## 使い方
第一引数はIM Frameworkを指定してください。選択肢は、`ibus|fcitx|fcitx5|uim|emacs`です。今回の例では`ibus`を指定しています。apt-srcのダウンロード、辞書データの適用、dpkgによるインストールが最後まで行われます。
```
curl -s https://raw.githubusercontent.com/PenguinCabinet/Mozc-UT-dpkg-installer/refs/heads/main/install.sh | bash -s -- ibus
```

`mozc-ut`にソースコードや辞書データ、dpkgなどが生成されます。`mozc-ut/dpkg`にdpkgが保存されています。
```



