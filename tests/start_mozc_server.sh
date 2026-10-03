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

# 古いサーバと学習履歴を掃除する
pkill mozc_server || true
sleep 1
rm -rf ~/.mozc

# まずフォアグラウンドで短時間動かし、即死するかを exit code で判定する。
# timeout の exit code が 124 なら「8秒間生存した」= 正常起動とみなす。
# それ以外 (139=SEGV, 134=ABORT, 0/1=サイレント終了など) は異常として
# ログ・ldd・データ配置を出して失敗させる。
echo "foreground probe (timeout 8s)..."
set +e
timeout -k 5 8 "$SERVER_BIN" >"$LOG" 2>&1
FG_CODE=$?
set -e
echo "foreground probe: exit=$FG_CODE (124=8秒生存=正常)"
if [ "$FG_CODE" -ne 124 ]; then
    echo "ERROR: mozc_server が起動しません (exit=$FG_CODE)。サーバログ:" >&2
    cat "$LOG" >&2 || true
    echo "--- ldd $SERVER_BIN ---" >&2
    ldd "$SERVER_BIN" >&2 || true
    echo "--- mozc-data files ---" >&2
    dpkg -L mozc-data 2>/dev/null | head -50 >&2 || true
    echo "--- processes ---" >&2
    pgrep -a mozc >&2 || true
    exit 2
fi

# 正常そうなのでバックグラウンドで本起動する
rm -rf ~/.mozc
"$SERVER_BIN" >"$LOG" 2>&1 &
SERVER_PID=$!
sleep 2
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
