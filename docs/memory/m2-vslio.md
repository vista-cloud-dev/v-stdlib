---
name: m2-vslio
description: VSL/MSL M2 Lane B DONE — VSLIO binds the STDNET socket seam to VistA's Kernel device handler (outbound TCP via CALL^%ZISTCP, ICR #2118). Re-pinned msl_ref v0.7.0→v0.8.0. Tier1 POP=0 + tier2 echo GREEN on vehu(YDB); CALL^%ZISTCP wired on both engines; IRIS loopback soft-skips on STDNET's deferred IRIS leg; tier3 TLS loud-blocked. 3 boundaries green.
metadata:
  type: project
---

# VSL T-M2 Lane B — VSLIO (VistA TCP transport over ^%ZISTCP), 2026-06-16

The VistA side of the M2 socket/TLS seam (S4): `VSLIO` binds the portable MSL
`STDNET` seam (MSL **v0.8.0**) to VistA's Kernel device handler. Branch
`m2-vslio` off v-stdlib `main`. Second `VSL*` module (after `VSLCFG`).

## Re-pin (boundary ①) — first real fetch-at-tag
`make pin` after hand-setting `dist/msl-seam-pin.json` `msl_ref` v0.7.0→**v0.8.0**:
syncs the `seams` block from the sibling m-stdlib `git show v0.8.0:dist/
seam-snapshot.json` → now carries **STDENV + STDNET** (6 verbs). `check-msl-pin`
green (2 seams match MSL@v0.8.0). This is the first real run of T0b.4's
fetch-the-contract-at-the-tag path (it had only ever SKIP'd before).

## The adapter — outbound CLIENT only (key design finding)
**VistA has NO Supported Kernel listen/accept (server) API** (corpus-confirmed:
Kernel Device Handler DG lists only the client-side `CALL^%ZISTCP`; inbound is the
listener-process/JOB pattern — `ZISTCP^XWBTCPM1` etc). So VSLIO binds the **client
subset** of STDNET's signature; the SERVER/listener side stays in portable STDNET
(never duplicated up — waterline §9 no-duplication).

API: `$$connect^VSLIO(host,port,timeout)`→handle · `$$read(id,max,to,.buf)` ·
`$$write(id,buf)` · `$$close(id)` · `$$lastError()`. The handle **is the opened
device** (`IO`, e.g. `SCK$57028`).

## CALL^%ZISTCP — the real API (the corpus doc was WRONG)
The vdocs gold doc describes an **input-variable** convention (`IPADDRESS`/`SOCKET`/
`TIMEOUT`, bare `D CALL^%ZISTCP`) — that is **wrong vs the live routine**. The
actual entry is **argument-passed**: `CALL(IP,SOCK,TO)`, i.e.
**`D CALL^%ZISTCP(host,port,timeout)`** (read the source on vehu with
`$T(CALL+i^%ZISTCP)`). `POP`=0 success / positive fail; on success **`IO`** holds
the socket device. The GT.M arm (`CGTM`) does `OPEN NIO:(CONNECT=IP_":"_SOCK_
":TCP":ATTACH="client"):TO:"SOCKET"` and **leaves the socket device CURRENT** — so
`connect` must `use pio` (restore `$IO`) BEFORE returning or its caller writes into
the socket. `CLOSE^%ZISTCP` reads `IO` (set `IO`=handle first) and calls
`HOME^%ZIS` → also save/restore `$IO` around it. `@icr 2118 @call CALL^%ZISTCP` +
`@call CLOSE^%ZISTCP`, `@source XU/krn_8_0_dg_device_handler_ug#callzistcp-…` /
`#closezistcp-…` (check-icr + check-citations green). Engine-portable: `^%ZISTCP`
branches by OS internally (CGTM/CONT), so VSLIO needs no `$ZVERSION` arm.

## Acceptance (tiered, both engines over the driver)
- **vehu (YDB) 10/10:** tier-1 `CALL^%ZISTCP`→POP=0 + tier-2 byte echo (loopback:
  raw **STDNET listener** for the server side — STDNET works on the GT.M VistA
  engine — and VSLIO `CALL^%ZISTCP` as the client; ping out, pong back) + the
  connect-failure + TLS-gap tests.
- **foia-t12 (IRIS) 6/6:** the connect-failure test (CALL^%ZISTCP `CONT` path →
  POP positive to a closed port → handle 0) proves the binding is wired on IRIS;
  TLS-gap tests pass; the **loopback soft-skips** (STDNET listener is YDB-only —
  STDNET's IRIS leg is the owed m-stdlib follow-up, so the IRIS POP=0+echo is
  blocked on it, not on VSLIO).
- Test staging: `m test --engine … --docker … [--namespace VISTA] --routines src
  --routines <m-stdlib>/src tests/VSLIOTST.m` (the Makefile `test` target now adds
  `--routines $(SRC)` so VSL* suites resolve, like the VSLCFGTST canonical cmd).

## TLS gap — loud (mirrors STDNET, per the standing directive)
`$$tlsAvailable^VSLIO()`=0; `$$connectTls^VSLIO` **raises `,U-VSLIO-NOTLS,`** (via
`raiseNoTls`, stashing `^TMP($job,"vslio","err")`) — never silent plaintext;
`$$tlsHelp`/`$$lastError` carry remediation (cert + `XU*8.0*787` / IRIS
`Security.SSLConfigs`; wire over the Kernel `INIT-XUTLS` #7616 + `ISTLSSERVERCONF-
XUSUDO` #7617). **Gotcha:** the remediation string must NOT contain literal
`^XUTLS`/`^XUSUDO` — `check-icr` scans code strings for `^XU*` and flags them as
undeclared L4 calls (write `INIT-XUTLS`/`ISTLSSERVERCONF-XUSUDO` with hyphens).
`m-lint disable-file=M-MOD-024` (device-handler input vars read as locals, like
STDNET). Tier-3 (real TLS echo) stays infra-blocked — the gating cleanup STDNET's
discoveries row already tracks.

## Gates (all green)
`make check-fast`: fmt/lint/`m arch check .` (layer v) + check-seams (0 — VSLIO is
the consumer, no @seam) + **check-icr (4: VSLCFG #2263 ×2 + VSLIO #2118 ×2)** +
**check-citations (4 vs gold corpus)** + check-namespaces (2 routines VSL) +
**check-msl-pin (v0.8.0)** + check-engine-access + check-kids. No KIDS/VSLBLD work
(that's M5); VSLIO is NOT in the VSL KIDS base yet.

**Next: M3** (VSLFS — the FileMan storage seam, §12.2). Owed for full M2: STDNET's
IRIS leg (unblocks the IRIS loopback) + tier-3 TLS (the gating infra cleanup).
