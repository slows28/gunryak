#!/usr/bin/env python3
"""Run genuine Godot 4.7.2 editor and battle regression tests.

Exits non-zero when the engine is absent, incompatible, a test errors, or the
success marker is missing. Do not confuse Python/mock self tests with Godot.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
GODOT_VERSION = "4.7.2"
TESTS = [
    ("import_and_parse", ["--headless", "--editor", "--import", "--path", "{project}", "--quit"], None),
    ("simulation", ["--headless", "--path", "{project}", "--script", "res://tests/smoke.gd"], "GUNRYAK_TEST_SUMMARY"),
    ("campaign_demo", ["--headless", "--path", "{project}", "--script", "res://tests/demo_smoke.gd"], "GUNRYAK_DEMO_PASS"),
    ("unit_combat", ["--headless", "--path", "{project}", "--script", "res://tests/combat_upgrades.gd"], "GUNRYAK_COMBAT_PASS"),
    ("formation_efficiency", ["--headless", "--path", "{project}", "--script", "res://tests/formation_efficiency.gd"], "GUNRYAK_FORMATION_EFFICIENCY_PASS"),
    ("tactics_playtest", ["--headless", "--path", "{project}", "--script", "res://tests/tactics_playtest.gd"], "GUNRYAK_TACTICS_PASS"),
    ("balance_matrix", ["--headless", "--path", "{project}", "--script", "res://tests/balance_matrix.gd"], "GUNRYAK_BALANCE_PASS"),
    ("field_operations", ["--headless", "--path", "{project}", "--script", "res://tests/field_operations.gd"], "GUNRYAK_FIELD_OPERATIONS_PASS"),
    ("post_deployment", ["--headless", "--path", "{project}", "--script", "res://tests/post_deployment.gd"], "GUNRYAK_POST_DEPLOYMENT_PASS"),
    ("field_judgment", ["--headless", "--path", "{project}", "--script", "res://tests/field_judgment.gd"], "GUNRYAK_FIELD_JUDGMENT_PASS"),
    ("linked_march", ["--headless", "--path", "{project}", "--script", "res://tests/linked_march.gd"], "GUNRYAK_LINKED_MARCH_PASS"),
    ("terrain_range", ["--headless", "--path", "{project}", "--script", "res://tests/terrain_range.gd"], "GUNRYAK_TERRAIN_RANGE_PASS"),
    ("wide_field", ["--headless", "--path", "{project}", "--script", "res://tests/wide_field.gd"], "GUNRYAK_WIDE_PASS"),
    ("six_armies", ["--headless", "--path", "{project}", "--script", "res://tests/six_armies.gd"], "GUNRYAK_SIX_PASS"),
    ("objectives", ["--headless", "--path", "{project}", "--script", "res://tests/objectives.gd"], "GUNRYAK_OBJECTIVES_PASS"),
    ("battle_audio", ["--headless", "--audio-driver", "Dummy", "--path", "{project}", "--script", "res://tests/battle_audio.gd"], "GUNRYAK_AUDIO_PASS"),
    ("scene", ["--headless", "--path", "{project}", "--script", "res://tests/scene_smoke.gd"], "GUNRYAK_SCENE_PASS"),
]


def resolve_godot(given: str | None) -> str | None:
    options = [given, os.environ.get("GODOT_BIN")]
    options += [shutil.which(name) for name in ("godot", "godot4")]
    if os.name == "nt":
        options += [str(p) for p in ROOT.glob("Godot*.exe")]
    for option in options:
        if not option:
            continue
        found = shutil.which(option)
        if found:
            return found
        if Path(option).is_file():
            return str(Path(option).resolve())
    return None


def run(cmd: list[str], cwd: Path, timeout: int) -> dict:
    start = time.monotonic()
    try:
        proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        return {
            "exit_code": proc.returncode,
            "output": proc.stdout + proc.stderr,
            "duration_s": round(time.monotonic() - start, 2),
            "timed_out": False,
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "exit_code": -1,
            "output": (exc.stdout.decode("utf-8", "replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")) + (exc.stderr.decode("utf-8", "replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")) + "\nTIMEOUT",
            "duration_s": round(time.monotonic() - start, 2),
            "timed_out": True,
        }


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=None, help="Path to Godot 4.7.2 executable")
    ap.add_argument("--project", type=Path, default=ROOT)
    ap.add_argument("--timeout", type=int, default=150)
    args = ap.parse_args()
    project = args.project.resolve()
    out_dir = project / "test_results"
    out_dir.mkdir(exist_ok=True)
    report = {
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "project": str(project),
        "expected_engine": GODOT_VERSION,
        "engine": None,
        "status": "NOT_RUN",
        "checks": [],
    }

    def save():
        (out_dir / "engine_test_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    binary = resolve_godot(args.godot)
    if not binary:
        print("ENGINE_UNAVAILABLE: Godot 4.7.2 executable not found. No engine test was performed.")
        report["reason"] = "Godot executable not found"
        save()
        return 3
    version_run = run([binary, "--version"], project, args.timeout)
    report["engine"] = version_run["output"].strip()
    if version_run["exit_code"] != 0 or not report["engine"].startswith(GODOT_VERSION):
        report["status"] = "BLOCKED_VERSION"
        report["reason"] = f"Expected Godot {GODOT_VERSION}, got {report['engine']!r}"
        save()
        print("ENGINE_VERSION_MISMATCH: " + report["reason"])
        return 4

    for name, template, expected_marker in TESTS:
        cmd = [binary] + [arg.replace("{project}", str(project)) for arg in template]
        # Five full battles with twenty field corps take over three minutes on a shared runner.
        budget = max(args.timeout, 420) if name == "six_armies" else args.timeout
        result = run(cmd, project, budget)
        output = result.pop("output")
        (out_dir / f"{name}.log").write_text(output, encoding="utf-8")
        check_ok = result["exit_code"] == 0 and not result["timed_out"]
        if expected_marker == "GUNRYAK_TEST_SUMMARY":
            check_ok &= bool(re.search(r"GUNRYAK_TEST_SUMMARY pass=\d+ fail=0(?:\s|$)", output))
        elif expected_marker:
            check_ok &= expected_marker in output
        check_ok &= "SCRIPT ERROR" not in output and "Parse Error" not in output
        entry = {"name": name, **result, "passed": bool(check_ok), "log": f"test_results/{name}.log"}
        report["checks"].append(entry)
        print(("PASS" if check_ok else "FAIL") + f" {name}: code={result['exit_code']}, {result['duration_s']}s")
        if not check_ok:
            report["status"] = "FAILED"
            report["reason"] = f"{name} failed; see {entry['log']}"
            save()
            print(output[-3000:])
            return 1
    report["status"] = "PASSED"
    save()
    print("GUNRYAK_GODOT_ENGINE_TESTS_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
