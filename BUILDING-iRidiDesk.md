# Building iRidiDesk

iRidiDesk is a modified incoming-support build based on RustDesk.

## License

This source package is provided under the GNU AGPLv3 terms, following the original RustDesk license.

## Build-time parameters

Production server parameters are not stored in this source package.

Create a local `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Do not commit production .env files.

## Windows x86 release build

Install the Rust toolchain once, including the 32-bit MSVC target:

```bash
rustup toolchain install stable
rustup target add i686-pc-windows-msvc
```

For an ARM64 build computer, install both **Desktop development with C++** and the **MSVC v143 – VS 2022 C++ ARM64 build tools** individual component. The script uses ARM64 tools for Rust's local build scripts and the x86 linker only for the final client, so the resulting package remains x86 (32-bit).

Then create the local release archive from PowerShell:

```powershell
.\scripts\build-release.ps1 -Version 1.0.2
```

The command builds `iRidiDesk.exe`, packages the required service, Sciter runtime and UI files, and produces `dist/iRidiDesk-<version>-win32.zip`. The `.env` file stays local and is never packaged or committed.

##Notes

This build is intended only for receiving incoming iRidi remote support connections.
Outgoing connection UI and server configuration UI are intentionally removed or hidden.
