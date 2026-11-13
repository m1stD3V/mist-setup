#!/usr/bin/env python3
"""Emit JSON metadata/preview for a file or directory.

Used by the file-search preview pane. Kept dependency-free so it works
on a minimal Arch install (python3 + file + pdftotext + ffprobe).
"""

import json
import os
import stat
import subprocess
import sys

TEXT_LIMIT = 2000
LINE_LIMIT = 20
DIR_LIMIT = 40


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
        return (r.stdout or "").strip()
    except Exception:
        return ""


def human_size(n):
    try:
        n = float(n)
    except Exception:
        return ""
    for unit in ("B", "K", "M", "G", "T"):
        if n < 1024 or unit == "T":
            return ("%d%s" % (n, unit)) if unit == "B" else ("%.1f%s" % (n, unit))
        n /= 1024.0
    return ""


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "no path"}))
        return
    path = sys.argv[1]
    out = {
        "path": path,
        "name": os.path.basename(path.rstrip("/")) or path,
        "kind": "file",
        "mime": "",
        "type": "",
        "size": 0,
        "sizeHuman": "",
        "modified": "",
        "perm": "",
        "entries": [],
        "text": "",
        "metadata": "",
        "error": "",
    }

    try:
        st = os.stat(path)
        out["size"] = st.st_size
        out["sizeHuman"] = human_size(st.st_size)
        out["modified"] = run(["date", "-d", "@%d" % int(st.st_mtime), "+%Y-%m-%d %H:%M"])
        out["perm"] = stat.filemode(st.st_mode)
        out["kind"] = "dir" if os.path.isdir(path) else "file"
        out["type"] = run(["file", "-b", path])
        out["mime"] = run(["file", "-b", "--mime-type", path])

        if out["kind"] == "dir":
            try:
                entries = sorted(os.listdir(path))
            except Exception as e:
                entries = []
                out["error"] = str(e)
            out["entries"] = entries[:DIR_LIMIT]
        elif out["mime"].startswith("text/") or out["mime"] in (
            "application/json",
            "application/xml",
            "application/javascript",
            "application/x-shellscript",
        ):
            with open(path, "r", errors="replace") as f:
                lines = []
                for i, line in enumerate(f):
                    if i >= LINE_LIMIT:
                        break
                    lines.append(line.rstrip("\n"))
            out["text"] = "\n".join(lines)[:TEXT_LIMIT]
        elif out["mime"] == "application/pdf":
            out["text"] = "\n".join(
                run(["pdftotext", "-l", "1", path, "-"]).splitlines()[:LINE_LIMIT]
            )[:TEXT_LIMIT]
        elif out["mime"].startswith(("audio/", "video/")):
            out["metadata"] = run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-show_entries",
                    "format=duration,size,bit_rate:stream=codec_name,width,height",
                    "-of",
                    "default=noprint_wrappers=1",
                    path,
                ]
            )
    except Exception as e:
        out["error"] = str(e)

    print(json.dumps(out))


if __name__ == "__main__":
    main()
