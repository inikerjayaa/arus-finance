# Arus Finance V30 — Vivo 1915 Android 12 UAT RC2

This checklist is the physical-device gate for the final V30 baseline after the Android/OEM biometric lifecycle fix. CI compile/test success is not treated as a physical-device PASS.

## 1. Fresh install / first use

- Fresh install opens onboarding without any usage-purpose survey.
- Flow is intentionally short: **Nama → PIN → Kode Pemulihan → Home**.
- PIN accepts 4–8 digits and requires confirmation.
- Recovery code is shown once, can be copied, and the flow cannot finish until the user confirms it was saved.
- The first Home session opens without asking for the newly-created PIN a second time.
- Home greeting uses the saved local name, for example **Selamat pagi, Ema**.

## 2. Root lock / privacy regression from physical UAT

- With PIN enabled, leave Arus while any sensitive dialog, bottom sheet, transaction detail, or account action is open.
- Reopen Arus.
- **No control below the lock may receive a tap or complete an action before authentication.**
- The lock must cover dialogs/routes immediately; there must be no “two actions still work” window.
- App-switcher privacy shield remains active when Arus leaves foreground.

## 3. Vivo fingerprint compatibility

- Enable biometrics in Arus Settings.
- Lock and reopen Arus.
- Vivo fingerprint prompt must be allowed even if the OEM biometric-enrollment list is empty while device biometric authentication is otherwise supported.
- A successful fingerprint result that arrives during Flutter's transient `inactive` state must keep the finance UI covered and unlock only on the immediately following `resumed` event.
- If Arus actually enters `hidden`, `paused`, or `detached` after that transient success, the pending result must be discarded and must never unlock the app later.
- Canceling the fingerprint prompt must not create an automatic retry loop.
- PIN fallback remains usable.
- Manual biometric retry remains available.

## 4. Forgot PIN / recovery

- On the lock screen choose **Lupa PIN?**.
- Recovery with the saved recovery code must allow creation of a new PIN.
- If biometrics were previously enabled in Arus, biometric PIN recovery may also be used.
- After a successful PIN reset, the old recovery code becomes invalid and a new recovery code is shown once.
- The replacement recovery code must be explicitly saved before returning to Arus.
- Wrong recovery attempts must not unlock finance data.

## 5. Settings CLEAN contract

- Settings keeps daily-use options visible and technical recovery/integrity options under **Lanjutan**.
- Normal Settings does not expose a routine **Nonaktifkan app lock** action.
- Changing an existing PIN requires the current PIN first.
- Creating or rotating the recovery code from Settings requires the current PIN first.
- The local display name can be edited and Home greeting follows the change.
- **Tentang Arus** is the final section and stays concise.

## 6. Home CLEAN contract

- Home header greets by local daypart and saved name.
- Primary finance highlight shows only **Total Saldo, Pemasukan, Pengeluaran**.
- The old redundant **Ringkasan / Keuanganmu hari ini** block is absent.
- There is no duplicate manual refresh action; pull-to-refresh remains available.
- Insight Arus is quiet/on-device: it may surface one useful insight, but must not spam the Home screen or invent a warning without enough evidence.

## 7. Accounts / balance adjustment

- User-facing copy uses **Akun**, not mixed Account/Accounts wording in touched flows.
- **Sesuaikan saldo** presents **Saldo Saat Ini → Saldo Baru → Simpan saldo** without asking the user for an adjustment reason.
- The resulting adjustment remains auditable in the transaction/log history with an automatic note.

## 8. Money-input consistency

- Planning Budget/Bill/Bill Payment/Transaksi rutin inputs format IDR while typing.
- Transaction Edit, Refund, and min/max filters use the same IDR formatter.
- Example: entering `1500000` displays `1.500.000` while the ledger value remains unchanged.

## 9. Completion rule

Physical-device PASS may only be recorded after the checks above are exercised on the target **Vivo 1915 / Android 12** using the APK produced from this exact RC2 source snapshot.
