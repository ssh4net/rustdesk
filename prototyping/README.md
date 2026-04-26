# Prototyping

Temporary experiments live here when they should stay outside the production
app flow.

## Toolbar Lab

The current toolbar refactor prototype is a standalone Flutter desktop target:

- Dart target: `flutter/lib/prototyping/main_toolbar_lab.dart`
- Main page: `flutter/lib/prototyping/toolbar_lab_page.dart`

It does not initialize RustDesk session state or global FFI. The goal is fast
UI iteration with hot reload.

### One-time native build

Flutter desktop still expects the Rust native library to exist once for the
desktop runner.

Linux:

```bash
cd /mnt/f/gh/rustdesk/rustdesk-client
cargo build --features flutter --lib
```

Windows PowerShell:

```powershell
cd F:\GH\rustdesk\rustdesk-client
cargo build --features flutter --lib
```

### Run the lab

Linux:

```bash
cd /mnt/f/gh/rustdesk/rustdesk-client
scripts/run_toolbar_lab_linux.sh
```

Windows PowerShell:

```powershell
cd F:\GH\rustdesk\rustdesk-client
.\scripts\run_toolbar_lab_windows.ps1
```

macOS:

```bash
cd /path/to/rustdesk-client
scripts/run_toolbar_lab_macos.sh
```

Use hot reload for visual tweaks. Only rebuild Cargo if you touch Rust or FFI.
