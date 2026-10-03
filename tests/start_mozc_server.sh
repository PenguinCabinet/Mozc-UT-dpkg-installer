#!/bin/bash
# mozc_server をクリーン起動し、疎通確認ができるまで待つ。
# 使い方: bash tests/start_mozc_server.sh /tmp/mozc_server.log
# 正常に READY になれば exit 0、異常があれば診断情報を表示して exit 2。
#
# ※呼び出し元リポジトリ直下 (tests/ の親) で実行される想定。
set -euo pipefail
cd "$(dirname "$0")/.."

LOG="${1:?usage: start_mozc_server.sh <logfile>}"

SERVER_BIN=$(find /usr -name mozc_server -type f 2>/dev/null | head -n 1)
if [ -z "$SERVER_BIN" ]; then
    echo "ERROR: mozc_server が見つかりません" >&2
    exit 2
fi
echo "SERVER_BIN=$SERVER_BIN"
echo "USER=$(id -un) UID=$(id -u) HOME=$HOME"

# 古いサーバと学習履歴を掃除する
pkill mozc_server || true
sleep 1
echo "--- lock/profile dir before cleanup ---"
ls -la ~/.mozc 2>/dev/null || echo "(no ~/.mozc)"
ls -la ~/.config/mozc 2>/dev/null || echo "(no ~/.config/mozc)"
ls /tmp/.mozc* 2>/dev/null || true
# mozc 2.29 系はプロファイルに ~/.config/mozc を使うが、親ディレクトリが
# 無いと素朴な mkdir が失敗してサーバが exit 255 で死ぬ。あらかじめ作る。
# (旧 ~/.mozc が残っているとそちらが優先されるため、両方掃除して固定する)
clean_profile() {
    mkdir -p ~/.config
    rm -rf ~/.config/mozc ~/.mozc
}
clean_profile

# 診断用: リダイレクト先ログと、Mozc が file sink に書く
# プロファイル側ログ (~/.config/mozc/*.log) の両方を出す。
dump_logs() {
    echo "--- redirect log ($LOG) ---"
    cat "$LOG" 2>/dev/null || true
    echo "--- profile dir ---"
    ls -la ~/.mozc 2>/dev/null || echo "(no ~/.mozc)"
    ls -la ~/.config/mozc 2>/dev/null || echo "(no ~/.config/mozc)"
    echo "--- profile logs ---"
    cat ~/.mozc/*.log ~/.config/mozc/*.log 2>/dev/null || echo "(no profile logs)"
}

# まずサーバを起動し、8秒間生き残るか見る。死んだ場合は wait で
# exit code を回収する (timeout コマンドを介さない方式)。
# 生き残ればそのまま本起動として使い、疎通確認に進む。
rm -rf ~/.mozc
"$SERVER_BIN" >"$LOG" 2>&1 &
SERVER_PID=$!
FG_CODE=""
for _ in $(seq 1 8); do
    sleep 1
    STATE=$(ps -o stat= -p "$SERVER_PID" 2>/dev/null || echo gone)
    case "$STATE" in
        *Z*|*X*|gone|*"")
            set +e
            wait "$SERVER_PID"
            FG_CODE=$?
            set -e
            break
            ;;
    esac
done
if [ -n "$FG_CODE" ]; then
    echo "ERROR: mozc_server が8秒以内に終了しました (exit=$FG_CODE)" >&2
    dump_logs >&2 || true
    echo "--- strace capture ---" >&2
    if command -v strace >/dev/null 2>&1; then
        clean_profile
        strace -f -e trace=process,file,network,ipc,signal \
            -o "$LOG.strace" timeout 8 "$SERVER_BIN" >/dev/null 2>&1 || true
        echo "--- strace tail ---" >&2
        tail -60 "$LOG.strace" >&2 || echo "(no strace output)" >&2
    else
        echo "(strace not installed)" >&2
    fi
    echo "--- ldd $SERVER_BIN ---" >&2
    ldd "$SERVER_BIN" >&2 || true
    echo "--- mozc-data files ---" >&2
    dpkg -L mozc-data 2>/dev/null | head -50 >&2 || true
    echo "--- mozc-server files ---" >&2
    dpkg -L mozc-server 2>/dev/null | head -30 >&2 || true
    echo "--- processes ---" >&2
    pgrep -a mozc >&2 || true
    exit 2
fi

# 8秒生存したので、このまま本起動として使い、疎通確認に進む。
STATE=$(ps -o stat= -p "$SERVER_PID" 2>/dev/null || echo gone)
echo "server pid=$SERVER_PID state=$STATE"

# サーバの初期化 (辞書ロード等) を待つ。最大約90秒。
for _ in $(seq 1 18); do
    if python3 tests/check_mozc_candidate.py --probe-only; then
        echo "mozc_server READY"
        exit 0
    fi
    sleep 5
done

echo "ERROR: mozc_server の準備ができませんでした。サーバログ:" >&2
dump_logs >&2 || true
pgrep -a mozc || true
exit 2
