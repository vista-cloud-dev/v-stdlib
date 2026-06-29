# v-stdlib — manifest index

v-stdlib unversioned; 6 modules; 40 public labels.

Generated from `dist/vsl-manifest.json`. One entry per module
with every public label: signature on the left, synopsis on the
right. For full per-label detail (params, returns, raises,
examples, source location), read the manifest entry directly.

## `VSLCFG`

VistA configuration adapter over XPAR (Parameter Tools).

- `$$get^VSLCFG(key, default)` — Read parameter `key` at the SYS entity; return `default` when unset.
- `$$getEffective^VSLCFG(key, default)` — Read the effective value across the parameter's entity precedence; else `default`.
- `$$lastError^VSLCFG()` — The last VSLCFG error message (the composed XPAR failure detail).
- `do set^VSLCFG(key, value)` — Set parameter `key` to `value` at the SYS entity; raise on a failed write.

_raises: `U-VSL-CFG-SET`_

## `VSLFS`

VistA FileMan storage adapter (FileMan DBS record store).

- `$$exists^VSLFS(file, iens)` — Return 1 iff record (file,iens) exists (its .01 reads without a DIERR).
- `$$find^VSLFS(file, value, index)` — The IENS of the UNIQUE record whose `index` lookup equals `value`, else "".
- `$$get^VSLFS(file, iens, field, default, flags)` — Read (file,iens,field) via $$GET1^DIQ; return value, else `default`.
- `$$gets^VSLFS(file, iens, fields, out, flags)` — Read several fields of one record in a single DBS round-trip (GETS^DIQ); count into out.
- `$$kill^VSLFS(file, iens)` — Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1.
- `$$lastError^VSLFS()` — The last VSLFS error message (the composed FileMan DIERR detail).
- `$$list^VSLFS(file, out, index)` — List the IENS of every record (via LIST^DIC) into out("ien,"); return the count.
- `$$set^VSLFS(file, iens, field, value)` — File `value` into (file,iens,field); return the resolved IENS, else raise.

_raises: `U-VSL-FS-DIERR`_

## `VSLIO`

VistA TCP transport adapter over the Kernel device handler.

- `$$close^VSLIO(id)` — Close an outbound connection opened by $$connect.
- `$$connect^VSLIO(host, port, timeout)` — Open an outbound TCP connection; return the device handle, else 0.
- `$$connectTls^VSLIO(host, port, timeout, config)` — UNIMPLEMENTED — raises, never opens plaintext.
- `$$lastError^VSLIO()` — The last VSLIO error message (e.g. the TLS-gap remediation).
- `$$read^VSLIO(id, maxlen, timeout, buf)` — Raw-read up to maxlen bytes from a handle.
- `$$tlsAvailable^VSLIO()` — 0 — VSLIO has no wired TLS (engine TLS infra + XU*8.0*787 absent).
- `$$tlsHelp^VSLIO()` — Human-readable remediation for the TLS gap (diagnostics/logs).
- `$$write^VSLIO(id, buf)` — Raw-write `buf` to a connected handle.

_raises: `U-VSLIO-NOTLS`_

## `VSLLOG`

VistA FileMan audit sink (the dedicated VSL AUDIT file).

- `$$auditFile^VSLLOG()` — The dedicated VSL AUDIT FileMan file number (single source of truth).
- `$$lastError^VSLLOG()` — The last VSLLOG error message (the composed FileMan detail).
- `$$query^VSLLOG(out, event, fromDt, toDt)` — Filter audit records by event and/or FileMan date range into out("ien,")=event; return the count.
- `$$read^VSLLOG(iens, rec)` — Read the audit record's typed fields into rec(); return the EVENT (.01), else "".
- `do write^VSLLOG(event, detail, duz, host)` — File one structured audit record; return the resolved IENS, else raise.

_raises: `U-VSL-LOG-WRITE`_

## `VSLSEC`

VistA identity/authorization adapter (Kernel).

- `$$active^VSLSEC(duz)` — 1 iff principal `duz` (default: ambient DUZ) is an active user who can sign on.
- `$$bySecid^VSLSEC(secid)` — The #200 IEN for a SecID via EN1^XUPSQRY (RPC XUPS PERSONQUERY), else "".
- `$$duz^VSLSEC()` — The ambient principal — +$GET(DUZ), the caller's NEW PERSON (#200) IEN.
- `$$hasKey^VSLSEC(key, duz)` — 1 iff `duz` (default: the ambient DUZ) holds security key `key`.
- `$$lastError^VSLSEC()` — The last VSLSEC error message (the composed malformed-call detail).
- `$$user^VSLSEC(duz)` — The #200 NAME for `duz` (default: the ambient DUZ), resolved via VSLFS.

_raises: `U-VSL-SEC-ARG`_

## `VSLTASK`

VistA TaskMan persistent-listener adapter (the process seam).

- `$$askStop^VSLTASK(ztsk)` — Request that queued/running task `ztsk` stop (cooperative-stop WRITE side).
- `$$lastError^VSLTASK()` — The last VSLTASK error message (the composed malformed-call / fault detail).
- `do pclear^VSLTASK(ztsk)` — Clear the persistent flag on task `ztsk` (inverse of $$persist) so TaskMan stops self-restarting it.
- `$$persist^VSLTASK(ztsk)` — Mark queued task `ztsk` persistent so TaskMan self-restarts it on a lock drop.
- `$$queue^VSLTASK(entry, desc, when)` — (private) headless ^%ZTLOAD queue (no device); return the task number, else 0.
- `$$running^VSLTASK()` — 1 iff the TaskMan scheduler is live (its ^%ZTSCH("RUN") heartbeat is fresh).
- `$$schedule^VSLTASK(entry, desc, when)` — Headless-queue a persistent listener at `entry`; return its task number.
- `$$stat^VSLTASK(ztsk)` — Report task `ztsk`'s TaskMan status code (0 Undefined .. 5 Interrupted) via STAT^%ZTLOAD.
- `$$stop^VSLTASK()` — 1 iff a stop has been requested of the currently-running task (cooperative stop).

_raises: `U-VSL-TASK-ARG`, `U-VSL-TASK-QUEUE`_

