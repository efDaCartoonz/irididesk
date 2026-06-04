# iRidiDesk

iRidiDesk is a modified incoming-support build based on RustDesk.

This build is intended for receiving remote support connections from iRidi support staff. It is not intended to be used as a general-purpose remote desktop client.

## Origin

Original project: RustDesk  
Original project repository: https://github.com/rustdesk/rustdesk  
Original license: GNU AGPLv3

Original RustDesk copyright notices are preserved in the source code.

## License

iRidiDesk is distributed under the GNU AGPLv3 terms, following the original RustDesk license.

See:

- `LICENSE-AGPL-3.0.txt`
- `NOTICE-iRidiDesk.txt`
- `THIRD-PARTY-NOTICES.txt`
- `SOURCE-OFFER.txt`

## Modification summary

Compared to the original RustDesk client, this build includes the following changes:

- rebranding to iRidiDesk;
- incoming-support client mode;
- outgoing connection UI removed or hidden;
- server configuration UI removed or hidden;
- production server parameters injected at build time;
- simplified main window showing only ID, one-time password, settings and connection status;
- custom application icon and runtime branding;
- English and Russian UI only;
- license and source-code notices added to the About dialog.

## Build

See `BUILDING-iRidiDesk.md`.

## Source code for release 1.0.0

https://github.com/efDaCartoonz/irididesk/releases/tag/v1.0.0
