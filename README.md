# mozc-ut-dpkg-installer
dpkg環境において[Mozc UT Dictionaries](https://utuhiro78.github.io/linuxplayers/mozc-ut.html)をワンライナーでインストールするスクリプトです。

テストCIを設定しており、スクリプトが実行できることを確認しています。
1. mozc-ut未適用のmozcを実行し、「やはりおれ」と入力して「やはり俺の青春ラブコメはまちがっている」が候補として出ないことを確認(出た場合、テストの前提が間違っているため失敗)
2. 続いて、install.shを実行する
3. 次に、mozc-ut適用済みmozcを実行し、「やはりおれ」と入力して「やはり俺の青春ラブコメはまちがっている」が候補として出ることを確認。これでmozc-utが適用されたことを確認

このリポジトリには、インストール手順が記されているだけで、Mozc UT Dictionariesの辞書データ等は一切含まれていません。

## 使い方
第一引数はIM Frameworkを指定してください。選択肢は、`ibus|fcitx|fcitx5|uim|emacs`です。今回の例では`ibus`を指定しています。apt-srcのダウンロード、辞書データの適用、dpkgによるインストールが最後まで行われます。
```
curl -s https://raw.githubusercontent.com/PenguinCabinet/Mozc-UT-dpkg-installer/refs/heads/main/install.sh | bash -s -- ibus
```

`mozc-ut`にソースコードや辞書データ、dpkgなどが生成されます。`mozc-ut/dpkg`にdpkgが保存されています。


