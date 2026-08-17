#!/usr/bin/env python3
"""
Non-interactive driver for the Open AG Patcher sandbox container.

Usage:
  driver.py status <manager_path> <agy_path>
  driver.py patch-all <manager_path> <agy_path>
  driver.py patch-manager <manager_path>
  driver.py patch-agy <agy_path>
  driver.py restore-manager <manager_path>
  driver.py restore-agy <agy_path>
  driver.py check-updates
  driver.py version

All interactive confirmations are auto-answered; any path that would
need a browser/download is turned into a hard error, and update checks
only ever happen via the explicit `check-updates` command (which the
host must opt into by giving this container a network).
"""
import os
import sys


def apply_automation_patches():
    import patcher.cli as cli
    import patcher.utils.captcha as captcha

    cli.confirmed = lambda *a, **k: True
    cli.pause = lambda *a, **k: None

    def _no_interactive(*a, **k):
        raise RuntimeError("interactive/download browser path reached (blocked in sandbox)")

    cli.offer_download_and_block = _no_interactive
    captcha.confirm_with_captcha = lambda *a, **k: True

    # Patch modules that captured `handle_patch_failure` at import time
    # so a "signature not found" never triggers a network update probe.
    import patcher.manager.patcher as mgr
    import patcher.agy.patcher as agy

    def _fail(node):
        def inner(*a, **k):
            raise RuntimeError(
                f"PATCH FAILED [{node}]: byte-signature not found (unsupported build?) "
                "or write error — nothing was modified."
            )
        return inner

    mgr.handle_patch_failure = _fail("Antigravity 2.0 / language_server")
    agy.handle_patch_failure = _fail("Antigravity CLI / agy")


def preflight_manager(manager_path):
    """Abort early if the installed Antigravity 2.0 is older than the patcher supports."""
    from patcher.manager.patcher import check_antigravity_version, VersionStatus
    from patcher.manager.discovery import find_asar_relative_to_manager

    asar = find_asar_relative_to_manager(manager_path)
    status, ver = check_antigravity_version(asar)
    print(f"[preflight] Antigravity 2.0 version: {ver or 'unknown'} ({status.value})")
    if status == VersionStatus.TOO_OLD:
        print("ERROR: installed Antigravity 2.0 is older than the minimum supported version.", file=sys.stderr)
        return False
    return True


def cmd_status(manager_path, agy_path):
    from patcher.manager.patcher import get_status as mgr_status
    from patcher.agy.patcher import get_status as agy_status

    print("STATUS:")
    if manager_path and os.path.isfile(manager_path):
        print(f"  language_server : {mgr_status(manager_path)[0]}")
    else:
        print(f"  language_server : (target missing) {manager_path or '-'}")
    if agy_path and os.path.isfile(agy_path):
        print(f"  agy             : {agy_status(agy_path)[0]}")
    else:
        print(f"  agy             : (target missing) {agy_path or '-'}")
    return 0


def cmd_patch_manager(manager_path):
    if not manager_path or not os.path.isfile(manager_path):
        print("ERROR: manager target not found.", file=sys.stderr)
        return 2
    if not preflight_manager(manager_path):
        return 2
    print("\n=== PATCH: Antigravity 2.0 (language_server) ===", flush=True)
    from patcher.manager.patcher import do_patch_manager
    do_patch_manager(manager_path)
    return 0


def cmd_patch_agy(agy_path):
    if not agy_path or not os.path.isfile(agy_path):
        print("ERROR: agy target not found.", file=sys.stderr)
        return 3
    print("\n=== PATCH: Antigravity CLI (agy) ===", flush=True)
    from patcher.agy.patcher import do_patch_agy
    do_patch_agy(agy_path)
    return 0


def cmd_patch_all(manager_path, agy_path):
    rc = 0
    try:
        rc = cmd_patch_manager(manager_path) or rc
    except Exception as e:
        print(f"[manager] {e}", file=sys.stderr)
        rc = 2
    try:
        rc = cmd_patch_agy(agy_path) or rc
    except Exception as e:
        print(f"[agy] {e}", file=sys.stderr)
        rc = 3
    cmd_status(manager_path, agy_path)
    return rc


def cmd_restore_manager(manager_path):
    if not manager_path or not os.path.isfile(manager_path):
        print("ERROR: manager target not found.", file=sys.stderr)
        return 2
    from patcher.manager.patcher import do_restore_manager
    do_restore_manager(manager_path)
    return 0


def cmd_restore_agy(agy_path):
    if not agy_path or not os.path.isfile(agy_path):
        print("ERROR: agy target not found.", file=sys.stderr)
        return 3
    from patcher.agy.patcher import do_restore_agy
    do_restore_agy(agy_path)
    return 0


def cmd_check_updates():
    from patcher.constants import VERSION
    from patcher.utils.update import check_for_updates, get_last_update_result

    print(f"patcher VERSION = {VERSION}")
    check_for_updates(silent=False, timeout=10)
    print(f"LAST_UPDATE_RESULT = {get_last_update_result()!r}")
    return 0


def cmd_version():
    from patcher.constants import VERSION
    print(VERSION)
    return 0


def main():
    apply_automation_patches()

    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return 1

    cmd, *args = argv

    if cmd == "status" and len(args) >= 2:
        return cmd_status(args[0], args[1])
    if cmd == "patch-all" and len(args) >= 2:
        return cmd_patch_all(args[0], args[1])
    if cmd == "patch-manager" and len(args) >= 1:
        return cmd_patch_manager(args[0])
    if cmd == "patch-agy" and len(args) >= 1:
        return cmd_patch_agy(args[0])
    if cmd == "restore-manager" and len(args) >= 1:
        return cmd_restore_manager(args[0])
    if cmd == "restore-agy" and len(args) >= 1:
        return cmd_restore_agy(args[0])
    if cmd == "check-updates":
        return cmd_check_updates()
    if cmd == "version":
        return cmd_version()

    print(f"unknown command: {cmd}", file=sys.stderr)
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())