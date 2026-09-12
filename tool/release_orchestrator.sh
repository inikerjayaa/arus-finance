#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmd="${1:-status}"
case "$cmd" in
  source)
    python3 tool/verify_ci_action_pins.py
    bash tool/run_all_audits.sh
    python3 tool/release_readiness_report.py --source-pass --json-out build/arus_evidence/release-readiness.json --md-out build/arus_evidence/release-readiness.md
    ;;
  status)
    python3 tool/release_readiness_report.py
    ;;
  compile)
    platform="${2:-all}"
    bash tool/native_compile_gate.sh "$platform"
    python3 tool/release_readiness_report.py --source-pass --json-out build/arus_evidence/release-readiness.json --md-out build/arus_evidence/release-readiness.md
    ;;
  store)
    platform="${2:-all}"
    bash tool/native_release_gate.sh "$platform"
    python3 tool/release_readiness_report.py --source-pass --json-out build/arus_evidence/release-readiness.json --md-out build/arus_evidence/release-readiness.md
    ;;
  *)
    echo "Usage: $0 [source|status|compile [android|ios|all]|store [android|ios|all]]" >&2
    exit 2
    ;;
esac
