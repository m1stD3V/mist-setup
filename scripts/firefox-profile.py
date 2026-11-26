#!/usr/bin/env python3
"""Print the default Firefox profile directory.

With --create, make a profile first when Firefox has never run, so the textfox
files and the generated theme have somewhere to go before the first launch.

Firefox 147 and later store profiles under $HOME/.config/mozilla/firefox;
older releases use $HOME/.mozilla/firefox. Both are checked.
"""

import configparser
import os
import sys

PROFILE_NAME = "mist.default-release"
# Hash of the standard /usr/lib/firefox install directory on Linux. Firefox
# uses it to remember which profile belongs to the system install; without it
# the Profile0 Default=1 entry is still honoured.
INSTALL_ID = "Install4F96D1932A9F858E"


def roots(home):
    for rel in (".config/mozilla/firefox", ".mozilla/firefox"):
        yield os.path.join(home, rel)


def read_ini(path):
    parser = configparser.RawConfigParser(strict=False)
    try:
        parser.read(path)
    except (configparser.Error, OSError):
        return None
    return parser


def find_profile(home):
    """Return the profile Firefox launches first, or ""."""
    for root in roots(home):
        ini = os.path.join(root, "profiles.ini")
        if not os.path.exists(ini):
            continue
        parser = read_ini(ini)
        if parser is None:
            continue

        known = {}
        for section in parser.sections():
            if not section.startswith("Profile"):
                continue
            try:
                path = parser.get(section, "Path")
                relative = parser.get(section, "IsRelative", fallback="1") == "1"
            except configparser.NoOptionError:
                continue
            full = os.path.join(root, path) if relative else path
            if os.path.isdir(full):
                known[full] = parser.get(section, "Default", fallback="0") == "1"
        if not known:
            continue

        for section in parser.sections():
            if not section.startswith("Install"):
                continue
            name = parser.get(section, "Default", fallback="")
            for full in known:
                if os.path.basename(full).lower() == name.lower():
                    return full
        for full, is_default in known.items():
            if is_default:
                return full
        return next(iter(known))
    return ""


def choose_root(home):
    root = ""
    for candidate in roots(home):
        if os.path.isdir(candidate):
            root = candidate
    # Neither exists yet: follow the layout current Firefox uses.
    return root or (home + "/.config/mozilla/firefox")


def create_profile(home):
    root = choose_root(home)
    profile = os.path.join(root, PROFILE_NAME)
    os.makedirs(profile, exist_ok=True)

    ini = os.path.join(root, "profiles.ini")
    if not os.path.exists(ini):
        text = (
            "[General]\n"
            "StartWithLastProfile=1\n"
            "Version=2\n"
            "\n"
            "[Profile0]\n"
            "Name=Mist\n"
            "IsRelative=1\n"
            f"Path={PROFILE_NAME}\n"
            "Default=1\n"
            "\n"
            f"[{INSTALL_ID}]\n"
            f"Default={PROFILE_NAME}\n"
            "Locked=1\n"
        )
        with open(ini, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        # A profiles.ini with no usable profile (for example after deleting the
        # old profile by hand): add ours alongside the stale entries.
        try:
            with open(ini, encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            text = ""
        numbers = []
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("[Profile") and line.endswith("]"):
                suffix = line[len("[Profile") : -1]
                if suffix.isdigit():
                    numbers.append(int(suffix))
        index = max(numbers) + 1 if numbers else 0
        if text and not text.endswith("\n"):
            text += "\n"
        text += (
            f"\n[Profile{index}]\n"
            "Name=Mist\n"
            "IsRelative=1\n"
            f"Path={PROFILE_NAME}\n"
            "Default=1\n"
        )
        with open(ini, "w", encoding="utf-8") as handle:
            handle.write(text)

    return profile


def main(argv):
    home = os.environ.get("HOME", os.path.expanduser("~"))
    path = find_profile(home)
    if not path and "--create" in argv[1:]:
        path = create_profile(home)
    print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
