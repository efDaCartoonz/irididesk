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

##Windows x86 build

Example build command used for this release:

```bash
set -a
source .env
set +a

cargo +stable-i686-pc-windows-msvc build --release
```

Required runtime packaging files:

```bash
target/release/rustdesk.exe
target/release/service.exe
target/release/sciter.dll
src/ui/
```

The final branded executable is copied as:

```bash
cp target/release/rustdesk.exe target/release/iRidiDesk.exe
```

##Notes

This build is intended only for receiving incoming iRidi remote support connections.
Outgoing connection UI and server configuration UI are intentionally removed or hidden.
