# Deal Finder — Flutter

Private, local-first Carousell deal tracking for Windows and Android. This app
runs Dart directly; it does not start Python, FastAPI or a localhost server.
The migration is **in progress**, not release-certified. See the repository's
`deal_finder_flutter_dart_implementation_plan.md` and `docs/flutter-migration.md`.

## Build and test

Validated development SDK: Flutter 3.47.2 / Dart 3.13.2. Use the included
`pubspec.lock`. Windows needs Visual Studio C++ Build Tools with CMake and a
Windows SDK plus the optional C++ ATL component required by secure storage.
Android uses compile SDK 37, AGP 9.1.1 and the Flutter-selected NDK.
Install SDK packages through Android Studio/SDK Manager and accept their terms.

From this directory, with Flutter on PATH:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter devices
flutter run -d <android-device-id>
```

After editing Drift tables:

```powershell
dart run build_runner build
dart run drift_dev schema dump lib/src/data/local/app_database.dart drift_schemas/app
dart run drift_dev schema generate --data-classes drift_schemas/app test/drift/app/generated
```

Add an explicit migration and migration tests; do not delete a user's database
to recover a schema error. Unit tests cover migrations from v1 through v4,
including populated v1→v2, v2→v3, v2→v4 and v3→v4 databases. Keep `--data-classes` when
regenerating migration helpers; the populated-data tests require those types.

Native smoke tests use a unique temporary database, a unique non-secret secure
storage probe, and fake marketplace/Gemini adapters. They do not use, clear or
replace the owner's credentials or live data:

```powershell
flutter test integration_test/app_smoke_test.dart -d <android-device-id> --no-uninstall
flutter test integration_test/app_smoke_test.dart -d windows --no-uninstall
```

Fixtures and test adapters are outside the release asset manifest. Golden tests
bundle the same fonts/icons as the app. Inspect changes before intentionally
regenerating goldens with `flutter test --update-goldens`.

After packaging, run the known-pattern artifact check from the repository root:

```powershell
.\tools\verify-release-archives.ps1 -SelfTest -ArchivePath deal_finder_app\build\app\outputs\flutter-apk\app-release.apk,deal_finder_app\build\artifacts\deal-finder-windows-1.0.0.zip
```

It streams decompressed entries without extracting files, checks prohibited
filenames and known credential/test-probe patterns in ASCII/UTF-8/UTF-16 data,
and prints only counts, hashes and detector names—not matched values. Synthetic
self-tests include read-boundary splits and size limits. This is a supplemental
check, not proof that arbitrary secrets, encrypted values or every token format
are absent. APK signature verification is a separate required check.

## Using the app

Targets outside the original Python alias catalog are supported. The named
core aliases are recall boosts; all other names use fuzzy recall. They are not
an allowlist of supported products. Latest scan shows only the last committed
snapshot; All saved finds includes retained history. Both hide dismissed items.
Dates use device-local time with explicit year-month-day and 24-hour fields,
not a hardcoded timezone; set the device timezone to Manila for Philippine time.

1. Add targets, thresholds and optional bundle policy on **Targets**.
2. Open the top-right menu → Settings and enter your own Gemini key. Credentials
   are stored using platform-protected secure storage, never in source/assets.
3. Start **Scan now** while the app is open. One run is allowed at a time;
   target edits apply to the next run. Normal results require Gemini verification.
4. Use **Deals** to view the latest committed scan or historical/favorite/
   dismissed items. Flags survive rediscovery. Metadata is local; uncached
   thumbnail images still require network access.
5. Use Settings → Sheets for explicit access checks, tab initialization,
   previewed target import/export, result sync or opt-in post-run sync.
   The service account must already have appropriate spreadsheet access.
   The app never grants sharing permissions or requests Google Drive scope.

Audit Mode is available through diagnostics. It calculates local fallback for
failed audit IDs, records a redacted report, and does not publish to Deals or
Sheets. Run reports distinguish failures, cancellation and warnings.

If any marketplace source fails, the scan continues checking the remaining
sources but keeps the previous committed Deals feed and skips result sync.
The warning means coverage was incomplete, not that those sources had no deals.
A fully successful scan with no matches does publish an empty current feed;
historical deals and their favorite/dismissed flags remain available.

Run history reports include source counts/durations/failure categories, audit
chunk outcomes, model/prompt/schema identifiers and the captured target policy.
Source and audit checkpoints are saved before the next work unit starts, so
cancellation or interruption retains completed diagnostics. Copied reports
redact sensitive values before JSON encoding and bound their size. They are
diagnostic summaries, not a complete replay archive: long text or very large
configurations are explicitly truncated, and credentials/descriptions/notes
are not included by the scan-report builder.

Separately, schema v4 stores the exact scan execution configuration introduced
in v3: requested
target IDs, resolved target policies/revisions, per-source limit, Audit Mode,
public auditor model/chunk size/prompt and schema hashes, and whether post-run
sync was enabled. These inputs are immutable and are saved during preparation,
before network work. Unresolved setup is recorded as unknown, not disabled or
empty; older runs remain without this record instead of inferring settings
from today's targets or a truncated report.

This private library record is not truncated or scrubbed, so it preserves exact
target names and keyword policies. It has no credential or non-execution-note
fields and is not copied by the diagnostic clipboard action. Library backups
include it. Configurations are limited to 16 MiB and 20,000 targets; unsupported
data fails preparation instead of being partially recorded. This is an input
snapshot, not an automatic replay of historical network responses.

## Release gates

The repository still needs native file-picker round-trip checks, complete parity and lifecycle checks,
visual sign-off and a real user-initiated Pixel 9 scan. Windows release and native
smoke tests on Windows/Pixel 9 have passed; this is not full release certification.
Never embed API keys or service-account JSON in a distributed application.

## Library backup and restore

Open the top-right menu → **Backup & restore**. Export saves a versioned JSON
file using the native file picker on Windows or Android. It contains targets
and policies, deal observations and flags, run history, committed snapshots,
and Sheets outbox payloads/checkpoints. Credentials, connection settings and
unrelated preferences are excluded. The file is **not encrypted** and retains
your notes and marketplace details: choose a private storage location.

Before restoring, export the current library if you may need to undo the
replacement. Choose a trusted backup, review the before/after record counts,
acknowledge replacement and confirm. The app validates the complete file,
checks for intervening edits, and replaces library tables in one transaction.
A failure rolls back the replacement. Scans and Sheets operations cannot run
concurrently with the backup workflow. Credentials/settings stay unchanged;
restored pending Sheets jobs require an explicit retry and unfinished scans
are marked interrupted, not resumed.

Backup format v2 supports Drift schema v4, up to 32 MiB and 20,000 records per
collection, bounded nesting and text lengths. Unsupported versions, duplicate
IDs/names/JSON keys, invalid types or provenance, missing current snapshots and
damaged sync payloads are rejected. Import/export never starts a Google API
request. This is a Flutter-library backup, not an importer for Python SQLite
files. Legacy Python data migration and retention remain separate work.

Existing format-v1/schema-v2 and format-v2/schema-v3 backups remain readable and
are upgraded in memory before preview/restore, without inventing missing run
configurations. Schema v4 stores the Sheets outbox in a dedicated table and
migrates prior `syncJob:*` app-state values without changing the portable format.
New format-v2 backups require the newer app. Export before upgrading, and do
not downgrade an older app over a database already migrated to schema v4.

## Offline parity fixtures

From the repository root, using the locked Python development environment:

```powershell
uv run python tools/test_offline_oracle.py
uv run python tools/export_flutter_fixtures.py
uv run python tools/export_flutter_safety_fixtures.py
uv run python tools/export_unicode_tables.py
```

These development generators exclude private environment/configuration and
disable network access for the application oracle. The Unicode generator has
no application imports. Generated expectations record source hashes and the
Python/RapidFuzz/Unicode versions; review changes when upgrading dependencies.
Run `flutter test test/safety_parity_test.dart` from the app directory afterward.
One explicitly approved difference preserves all candidate targets instead of
Python's first-target fallback bug. The Python expected output remains in the
fixture alongside that approved result. Full migration acceptance remains open.

`dart run tool/marketplace_probe.dart --live` is a separate, explicitly enabled
read-only category transport check. It prints counts/failure status only; it
does not load credentials, modify the library, or contact Gemini/Sheets. It is
not an end-to-end scan and is never run by the offline test suite.

## Private Android signing

Release signing requires `DEAL_FINDER_STORE_FILE`, `DEAL_FINDER_STORE_PASSWORD`,
`DEAL_FINDER_KEY_ALIAS` and `DEAL_FINDER_KEY_PASSWORD` in the build process's
environment. Missing credentials fail signing; release never uses the debug key.
Do not put these values in source files, command histories or logs.

The Windows helper `tools/build-android-release.ps1` (at the repository root)
loads the password from Windows-account-protected DPAPI storage and supplies it
to the child build process. Its first-time `-CreateSigningKey` switch explicitly
creates a key outside the repository; subsequent builds reuse that same key.

```powershell
# From the repository root; Flutter must be on PATH or pass -FlutterPath.
.\tools\build-android-release.ps1 -CreateSigningKey
.\tools\build-android-release.ps1
```

Keep a secure, recoverable backup of the keystore **and** its password. The
DPAPI password file is bound to this Windows user and computer; copying that
file to another machine is not a portable password backup. Losing the key or
password prevents updating already-installed private releases with the same
application identity. Do not regenerate it as a troubleshooting step.

The release helper intentionally permits Flutter's Pub preparation. With this
Flutter SDK, `--no-pub` after integration testing can leave a stale Android
plugin registrant referencing the development-only test plugin. Do not manually
edit generated registrants or move test plugins into production dependencies.
Run native builds sequentially in a checkout because generated files are shared.

The release application ID is `com.dealfinder.personal`; debug builds add
`.debug` and display **Deal Finder Dev**. Earlier migration previews use
`com.dealfinder.deal_finder_app` and are not automatically deleted or migrated.
Each identity has separate local data and credentials.
