"""Jembatan CLI ke MCP bawaan Roblox Studio (StudioMCP.exe lewat %LOCALAPPDATA%\\Roblox\\mcp.bat).

Dipakai bila integrasi MCP native agen belum aktif. Studio harus terbuka dengan
Assistant -> Manage MCP Servers -> "Enable Studio as MCP server" menyala.

Contoh:
  python scripts/studio_mcp.py tools                       # daftar tool + skema
  python scripts/studio_mcp.py status                      # list_roblox_studios + get_studio_state
  python scripts/studio_mcp.py call get_console_output '{}'
  python scripts/studio_mcp.py luau scripts/bake-command.luau --dm Edit
  python scripts/studio_mcp.py call screen_capture '{}' --out build/captures/udara.png

Gambar hasil tool (screen_capture) disimpan ke --out (default build/captures/<waktu>.png).
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class StudioMcp:
    def __init__(self, timeout: float = 60.0):
        bat = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "mcp.bat")
        if not os.path.exists(bat):
            raise SystemExit(f"mcp.bat tidak ditemukan: {bat}")
        self.proc = subprocess.Popen(
            ["cmd.exe", "/c", bat],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.timeout = timeout
        self.messages: list[dict] = []
        self.stderr: list[str] = []
        self._next_id = 1
        threading.Thread(target=self._read_out, daemon=True).start()
        threading.Thread(target=self._read_err, daemon=True).start()

    def _read_out(self) -> None:
        assert self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.decode("utf-8", "replace").strip()
            if not line:
                continue
            try:
                self.messages.append(json.loads(line))
            except json.JSONDecodeError:
                pass

    def _read_err(self) -> None:
        assert self.proc.stderr is not None
        for raw in self.proc.stderr:
            self.stderr.append(raw.decode("utf-8", "replace").rstrip())

    def _send(self, obj: dict) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write((json.dumps(obj) + "\n").encode("utf-8"))
        self.proc.stdin.flush()

    def request(self, method: str, params: dict | None = None, timeout: float | None = None) -> dict:
        rid = self._next_id
        self._next_id += 1
        self._send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}})
        deadline = time.time() + (timeout or self.timeout)
        while time.time() < deadline:
            for msg in list(self.messages):
                if msg.get("id") == rid:
                    self.messages.remove(msg)
                    return msg
            time.sleep(0.05)
        raise TimeoutError(f"Tidak ada jawaban untuk {method} dalam {timeout or self.timeout} dtk")

    def initialize(self) -> dict:
        res = self.request("initialize", {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "pantai-mancing-bridge", "version": "1.0"},
        }, timeout=30)
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return res

    def tools(self, attempts: int = 6) -> list[dict]:
        # Proxy menunggu Studio mendaftarkan tool (~10 dtk per percobaan); ulangi bila masih kosong.
        for _ in range(attempts):
            try:
                res = self.request("tools/list", {}, timeout=40)
            except TimeoutError:
                continue
            tools = res.get("result", {}).get("tools", [])
            if tools:
                return tools
            time.sleep(1.0)
        return []

    def call(self, name: str, args: dict, timeout: float | None = None) -> dict:
        return self.request("tools/call", {"name": name, "arguments": args}, timeout=timeout)

    def close(self) -> None:
        try:
            self.proc.kill()
        except OSError:
            pass


def print_result(res: dict, out: str | None) -> int:
    if "error" in res:
        print("ERROR:", json.dumps(res["error"], ensure_ascii=False))
        return 1
    result = res.get("result", {})
    code = 1 if result.get("isError") else 0
    img_index = 0
    for item in result.get("content", []):
        kind = item.get("type")
        if kind == "text":
            print(item.get("text", ""))
        elif kind == "image":
            data = base64.b64decode(item.get("data", ""))
            mime = item.get("mimeType", "image/png")
            ext = ".jpg" if "jpeg" in mime else ".png"
            if out:
                path = Path(out)
                if img_index > 0:
                    path = path.with_name(f"{path.stem}_{img_index}{path.suffix or ext}")
            else:
                path = ROOT / "build" / "captures" / f"{time.strftime('%Y%m%d-%H%M%S')}_{img_index}{ext}"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            print(f"[gambar] {path}")
            img_index += 1
        else:
            print(json.dumps(item, ensure_ascii=False)[:2000])
    if result.get("structuredContent"):
        print(json.dumps(result["structuredContent"], ensure_ascii=False)[:4000])
    return code


def main() -> int:
    ap = argparse.ArgumentParser(description="Jembatan MCP Roblox Studio")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("tools")
    sub.add_parser("status")
    pc = sub.add_parser("call")
    pc.add_argument("tool")
    pc.add_argument("args", nargs="?", default="{}")
    pc.add_argument("--out")
    pc.add_argument("--timeout", type=float, default=120)
    pl = sub.add_parser("luau")
    pl.add_argument("file")
    pl.add_argument("--dm", default="Edit", help="datamodel_type: Edit | Server | Client")
    pl.add_argument("--studio", default=None, help="studio_id (opsional)")
    pl.add_argument("--timeout", type=float, default=300)
    a = ap.parse_args()

    mcp = StudioMcp()
    try:
        mcp.initialize()
        tools = mcp.tools()
        if not tools:
            print("Studio belum menyediakan tool. Pastikan Studio terbuka dan 'Enable Studio as MCP server' aktif.")
            print("\n".join(mcp.stderr[-5:]))
            return 2
        names = {t["name"] for t in tools}
        if a.cmd == "tools":
            for t in tools:
                schema = t.get("inputSchema", {})
                req = set(schema.get("required", []))
                print(f"## {t['name']}\n  {t.get('description', '').strip()[:400]}")
                for k, v in schema.get("properties", {}).items():
                    print(f"  - {k}{'*' if k in req else ''}: {json.dumps(v, ensure_ascii=False)[:300]}")
            return 0
        if a.cmd == "status":
            code = 0
            for tool in ("list_roblox_studios", "get_studio_state"):
                if tool in names:
                    print(f"=== {tool}")
                    code |= print_result(mcp.call(tool, {}, timeout=60), None)
            return code
        if a.cmd == "call":
            args = json.loads(a.args)
            return print_result(mcp.call(a.tool, args, timeout=a.timeout), a.out)
        if a.cmd == "luau":
            src = Path(a.file).read_text(encoding="utf-8")
            args = {"code": src, "datamodel_type": a.dm}
            if a.studio:
                args["studio_id"] = a.studio
            return print_result(mcp.call("execute_luau", args, timeout=a.timeout), None)
    finally:
        mcp.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
