#!/usr/bin/env python3
"""mozc_emacs_helper 経由で Mozc の変換候補を検証するスクリプト.

生の mozc / UT適用済み mozc のどちらに対しても同じ手順で問い合わせる:

1. mozc_emacs_helper を起動し、CreateSession でセッションを作る
2. ひらがな読み (既定: "やはりおれ") を key_string として一括送信する
   ※ この時点の出力に予測候補 (SUGGESTION/PREDICTION) が含まれる
3. space で変換し、候補ウィンドウを確認する
4. pagedown で数ページ分めくって候補を確認する
5. フルリーディング (既定: "やはりおれのせいしゅんらぶこめはまちがっている")
   でも同様に 2-4 を行う (辞書エントリの読みが長い場合への保険)

終了コード:
  0 = 期待フレーズが候補に見つかった (FOUND)
  1 = 見つからなかった (NOT FOUND)
  2 = テスト自体のエラー (helper不在、通信失敗など)

--probe-only の終了コード:
  0 = サーバ疎通OK (READY)
  1 = サーバ疎通NG (NOT READY: helper不在・サーバ未起動・応答なしのいずれか)

呼び出し側 (GitHub Actions) で期待値と組み合わせる想定:
  - 生mozc: exit 1 であること (exit 0 なら「テストの前提が間違っています」)
  - 適用済みmozc: exit 0 であること
"""

import argparse
import re
import shutil
import subprocess
import sys

DEFAULT_READING = "やはりおれ"
DEFAULT_FULL_READING = "やはりおれのせいしゅんらぶこめはまちがっている"
DEFAULT_EXPECTED = "やはり俺の青春ラブコメはまちがっている"

HELPER_CANDIDATES = [
    "/usr/lib/mozc/mozc_emacs_helper",
    "/usr/libexec/mozc_emacs_helper",
    "/usr/bin/mozc_emacs_helper",
]

SESSION_RE = re.compile(r"\(emacs-session-id\s*\.\s*(\d+)\)")


def find_helper(explicit=None):
    if explicit:
        return explicit
    which = shutil.which("mozc_emacs_helper")
    if which:
        return which
    for path in HELPER_CANDIDATES:
        if shutil.which(path) or _is_executable(path):
            return path
    return None


def _is_executable(path):
    import os

    return os.path.isfile(path) and os.access(path, os.X_OK)


def quote_s_expr_string(s):
    # 読み・フレーズに " や \ は含まれない想定だが念のためエスケープする
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


class HelperSession:
    def __init__(self, helper_path):
        try:
            self.proc = subprocess.Popen(
                [helper_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=sys.stderr,
                text=True,
                encoding="utf-8",
                bufsize=1,
            )
        except OSError as e:
            print(f"ERROR: helper の起動に失敗しました: {e}", file=sys.stderr)
            sys.exit(2)
        self.event_id = 0
        # greeting 行を読み捨てる (来なくても先へ進む)
        try:
            greeting = self.proc.stdout.readline()
            if greeting:
                print(f"[helper greeting] {greeting.strip()}")
        except Exception as e:  # noqa: BLE001
            print(f"ERROR: helper greeting の読み取りに失敗: {e}", file=sys.stderr)
            sys.exit(2)

    def _next_event(self):
        self.event_id += 1
        return self.event_id

    def _roundtrip(self, line):
        if self.proc.poll() is not None:
            print(f"ERROR: helper が終了しています (code={self.proc.returncode})", file=sys.stderr)
            sys.exit(2)
        # print(f">>> {line}")
        try:
            self.proc.stdin.write(line + "\n")
            self.proc.stdin.flush()
        except BrokenPipeError:
            print("ERROR: helper への送信に失敗しました (broken pipe)", file=sys.stderr)
            sys.exit(2)
        resp = self.proc.stdout.readline()
        if not resp:
            print("ERROR: helper からの応答がありません", file=sys.stderr)
            sys.exit(2)
        return resp

    def create_session(self):
        eid = self._next_event()
        resp = self._roundtrip(f"({eid} CreateSession)")
        m = SESSION_RE.search(resp)
        if not m:
            print(f"ERROR: セッションIDの取得に失敗しました: {resp.strip()}", file=sys.stderr)
            sys.exit(2)
        sid = int(m.group(1))
        return sid, resp

    def send_key(self, sid, *keys):
        eid = self._next_event()
        resp = self._roundtrip(f"({eid} SendKey {sid} {' '.join(keys)})")
        return resp

    def delete_session(self, sid):
        eid = self._next_event()
        try:
            self._roundtrip(f"({eid} DeleteSession {sid})")
        except SystemExit:
            pass

    def close(self):
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
        except Exception:  # noqa: BLE001
            pass
        try:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        except Exception:  # noqa: BLE001
            try:
                self.proc.kill()
            except Exception:  # noqa: BLE001
                pass


def probe_once(helper_path):
    """サーバ疎通確認を1回だけ行う。応答があれば True.

    CreateSession はサーバと通信しないため、実際に SendKey を投げて
    サーバが生きているか確認する。helper は SendKey 失敗時に自ら
    終了してしまうため、呼び出し側は毎回新しい helper で試すこと。
    この関数自体は一切 exit しない。
    """
    try:
        proc = subprocess.Popen(
            [helper_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            bufsize=1,
        )
    except OSError:
        return False
    try:
        if not proc.stdout.readline():
            return False
        proc.stdin.write("(1 CreateSession)\n")
        proc.stdin.flush()
        m = SESSION_RE.search(proc.stdout.readline() or "")
        if not m:
            return False
        # 無害なキー (IME ON) でサーバと実際に往復させる
        proc.stdin.write(f"(2 SendKey {m.group(1)} on)\n")
        proc.stdin.flush()
        resp = proc.stdout.readline() or ""
        return "(error" not in resp
    except (BrokenPipeError, OSError, ValueError):
        return False
    finally:
        try:
            if proc.stdin:
                proc.stdin.close()
        except Exception:  # noqa: BLE001
            pass
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except Exception:  # noqa: BLE001
            try:
                proc.kill()
            except Exception:  # noqa: BLE001
                pass


def check_one_reading(helper, reading, expected, pages, debug_label):
    """1つの読みについて変換テストを行い、(found, outputs) を返す."""
    outputs = []
    sid, resp = helper.create_session()
    outputs.append(resp)
    print(f"[{debug_label}] session={sid}, reading={reading}")
    try:
        # ひらがなを直接 key_string として投入する
        resp = helper.send_key(sid, quote_s_expr_string(reading))
        outputs.append(resp)
        print(f"[{debug_label}] after input: {resp.strip()[:500]}")

        # 変換 (space)
        resp = helper.send_key(sid, "space")
        outputs.append(resp)
        print(f"[{debug_label}] after space: {resp.strip()[:500]}")

        # ページめくり (予測/変換どちらのウィンドウにも効く)
        for _ in range(pages):
            resp = helper.send_key(sid, "pagedown")
            outputs.append(resp)
        if pages:
            print(f"[{debug_label}] after pagedown x{pages}: {outputs[-1].strip()[:500]}")
    finally:
        helper.delete_session(sid)

    found = any(expected in out for out in outputs)
    return found, outputs


def main():
    ap = argparse.ArgumentParser(description="Mozc 変換候補の有無を検証する")
    ap.add_argument("--helper", default=None, help="mozc_emacs_helper のパス")
    ap.add_argument("--reading", default=DEFAULT_READING, help="短い読み (既定: やはりおれ)")
    ap.add_argument(
        "--full-reading",
        default=DEFAULT_FULL_READING,
        help="フルセンテンスの読み (既定: やはりおれのせいしゅんらぶこめはまちがっている)",
    )
    ap.add_argument("--skip-full-reading", action="store_true", help="フルリーディングのテストを省略する")
    ap.add_argument("--expected", default=DEFAULT_EXPECTED, help="探す候補フレーズ")
    ap.add_argument("--pages", type=int, default=5, help="pagedown でめくるページ数 (既定: 5)")
    ap.add_argument(
        "--probe-only",
        action="store_true",
        help="サーバ疎通確認のみ行う (READY/NOT READY, exit 0/1)",
    )
    args = ap.parse_args()

    helper_path = find_helper(args.helper)
    if args.probe_only:
        # リトライループから呼ばれる想定のため、出力は1行のみにする
        if helper_path and probe_once(helper_path):
            print("READY")
            return 0
        print("NOT READY")
        return 1
    if not helper_path:
        print(
            "ERROR: mozc_emacs_helper が見つかりません。"
            " (emacs-mozc-bin / emacs-mozc をインストールしてください)",
            file=sys.stderr,
        )
        return 2
    print(f"helper: {helper_path}")

    helper = HelperSession(helper_path)
    try:
        found_short, _ = check_one_reading(helper, args.reading, args.expected, args.pages, "prefix")
        found_full = False
        if not args.skip_full_reading:
            found_full, _ = check_one_reading(
                helper, args.full_reading, args.expected, args.pages, "full"
            )
        found = found_short or found_full
    finally:
        helper.close()

    if found:
        print(f"FOUND: 候補に {args.expected!r} が含まれています")
        return 0
    else:
        print(f"NOT FOUND: 候補に {args.expected!r} は含まれていません")
        return 1


if __name__ == "__main__":
    sys.exit(main())
