#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/reference_financial_audit.py
python3 tool/local_only_source_audit.py
python3 tool/dart_source_audit.py
python3 tool/dart_delimiter_audit.py
python3 tool/reference_local_durability_audit.py
python3 tool/reference_schema_migration_audit.py
python3 tool/reference_csv_import_audit.py
python3 tool/reference_import_scale_audit.py
python3 tool/notification_source_audit.py
python3 tool/reference_large_history_audit.py
python3 tool/compile_risk_audit.py
python3 tool/deep_mine_v9_source_audit.py
python3 tool/deep_mine_v10_source_audit.py
python3 tool/deep_mine_v11_source_audit.py
python3 tool/deep_mine_v12_source_audit.py
python3 tool/deep_mine_v13_recovery_audit.py
python3 tool/deep_mine_v14_survival_audit.py
python3 tool/deep_mine_v15_native_readiness_audit.py
python3 tool/deep_mine_v16_native_truth_audit.py
python3 tool/deep_mine_v17_native_execution_audit.py
python3 tool/deep_mine_v18_ux_accessibility_audit.py
python3 tool/deep_mine_v19_workflow_stress_audit.py
python3 tool/deep_mine_v20_long_session_audit.py
python3 tool/deep_mine_v21_rebuild_isolation_audit.py
python3 tool/deep_mine_v22_atomic_filter_state_audit.py
python3 tool/deep_mine_v23_privacy_shield_audit.py
python3 tool/pre_native_rc_v24_audit.py
python3 tool/deep_mine_v25_ci_handoff_audit.py
python3 tool/reference_v25_ci_handoff_audit.py
python3 tool/deep_mine_v26_release_orchestration_audit.py
python3 tool/reference_v26_release_orchestration_audit.py
# Historical Python fixtures may legitimately create bytecode caches while running.
# V27 canonical Git identity must be built only after those transient audit artifacts
# are removed, and the V27 bootstrap still fails closed on any residue afterward.
find . -type d -name __pycache__ -prune -exec rm -rf {} +
find . -type f -name '*.pyc' -delete
python3 tool/deep_mine_v27_git_bootstrap_audit.py
python3 tool/deep_mine_biometric_cancel_audit.py
python3 tool/reference_v27_git_bootstrap_audit.py
python3 tool/reference_v17_native_execution_audit.py
python3 tool/version_continuity_audit.py
python3 tool/reference_native_hardening_audit.py
python3 tool/reference_android_signing_audit.py
printf '\nPASS: all non-native Arus audits\n'
