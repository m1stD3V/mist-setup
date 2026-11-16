#!/usr/bin/env bash
# Syntax-check a Quickshell configuration before it is trusted.
#
# The qs.* imports have no qmldir files, so qmllint reports unresolved imports
# and unqualified accesses for every file. Those are expected; what matters
# here is the [syntax] category, which catches the mistakes a hand edit or a
# bad merge actually makes (unbalanced braces, a bad token, a truncated file).
#
# Qt5 also ships binaries called qmllint/qmlformat in /usr/sbin on some
# systems, and they silently fail on Qt6 QML. This script picks a Qt6 qmllint
# explicitly.
#
# usage: check-quickshell.sh [path] [--run]
#   path   Quickshell config directory (default: ~/.config/quickshell)
#   --run  also start the shell for a few seconds and fail on QML warnings
#          (needs a running Wayland session; not used by the installer)
set -Eeuo pipefail

path="$HOME/.config/quickshell"
run=0
for arg in "$@"; do
  case "$arg" in
    --run) run=1 ;;
    -*) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    *) path="$arg" ;;
  esac
done

die() {
  printf 'fail %s\n' "$*" >&2
  exit 1
}

find_qmllint() {
  local candidate
  local -a candidates=()
  [[ -n "${QT6_BIN:-}" ]] && candidates+=("$QT6_BIN/qmllint")
  command -v qmllint6 >/dev/null && candidates+=("$(command -v qmllint6)")
  candidates+=(/usr/lib/qt6/bin/qmllint)
  command -v qmllint >/dev/null && candidates+=("$(command -v qmllint)")
  if command -v qtpaths6 >/dev/null; then
    candidates+=("$(qtpaths6 --query QT_INSTALL_BINS 2>/dev/null)/qmllint")
  fi
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if "$candidate" --version 2>/dev/null | head -n1 | grep -q '^qmllint 6\.'; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

[[ -d "$path" ]] || die "not a directory: $path"
[[ -f "$path/shell.qml" ]] || die "no shell.qml in $path"

lint="$(find_qmllint)" || die "no Qt6 qmllint found (install qt6-declarative)"

failures=0
checked=0
while IFS= read -r -d '' file; do
  checked=$((checked + 1))
  output="$("$lint" "$file" 2>&1 || true)"
  if grep -q '\[syntax\]' <<<"$output"; then
    printf '  syntax error: %s\n' "${file#"$path"/}" >&2
    grep -A2 '\[syntax\]' <<<"$output" >&2
    failures=$((failures + 1))
  fi
done < <(find "$path" -type f -name '*.qml' -print0 | sort -z)

if ((failures > 0)); then
  die "$failures of $checked QML file(s) failed to parse"
fi
printf 'ok %s QML file(s) parsed\n' "$checked"

if ((run)); then
  command -v quickshell >/dev/null || die "quickshell not found"
  log_file="$(mktemp)"
  trap 'rm -f "$log_file"' EXIT
  status=0
  timeout 12 quickshell -p "$path" >"$log_file" 2>&1 || status=$?
  # 124 is the expected timeout: the shell was still running when time ran out.
  if ((status != 0 && status != 124)); then
    cat "$log_file" >&2
    die "quickshell exited with status $status"
  fi
  # Ignore the warnings a second instance always produces (socket, polkit,
  # notification registration) and fail on QML errors only.
  pattern='ReferenceError|TypeError|is not defined|Binding loop detected|Cannot assign|Unable to assign|\[syntax\]'
  if grep -E "$pattern" "$log_file" >/dev/null; then
    grep -E "$pattern" "$log_file" >&2
    die "QML errors while running $path"
  fi
  printf 'ok shell started without QML errors\n'
fi
