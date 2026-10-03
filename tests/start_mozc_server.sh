#!/bin/bash
# mozc_server をクリーン起動し、疎通確認ができるまで待つ。
# 使い方: bash tests/start_mozc_server.sh /tmp/mozc_server.log
# 正常に READY になれば exit 0、異常があればサーバログを表示して exit 2。
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

# 古いサーバと学習履歴を掃除する
pkill mozc_server || true
sleep 1
rm -rf ~/.mozc

"$SERVER_BIN" >"$LOG" 2>&1 &
SERVER_PID=$!

# 起動直後の死亡 (defunct を含む) を検出する
sleep 3
STATE=$(ps -o stat= -p "$SERVER_PID" 2>/dev/null || echo gone)
echo "server pid=$SERVER_PID state=$STATE"
case "$STATE" in
    *Z*|*X*|gone|"")
        echo "ERROR: mozc_server が起動直後に終了しました。サーバログ:" >&2
        cat "$LOG" >&2 || true
        exit 2
        ;;
esac

# サーバの初期化 (辞書ロード等) を待つ。最大約90秒。
for _ in $(seq 1 18); do
    if python3 tests/check_mozc_candidate.py --probe-only; then
        echo "mozc_server READY"
        exit 0
    fi
    sleep 5
done

echo "ERROR: mozc_server の準備ができませんでした。サーバログ:" >&2
cat "$LOG" >&2 || true
pgrep -a mozc || true
exit 2
