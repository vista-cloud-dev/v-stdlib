---
module: VSLIO
layer: v
since: 
stable: stable
synopsis: 'VistA TCP transport adapter over the Kernel device handler'
labels: ['close', 'connect', 'connectTls', 'lastError', 'read', 'tlsAvailable', 'tlsHelp', 'write']
errors: ['U-VSLIO-NOTLS']
see_also: []
doc_type: [REFERENCE]
---

# `VSLIO` — VistA TCP transport adapter over the Kernel device handler

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `close` | `$$close^VSLIO(id)` | Close an outbound connection opened by $$connect. |
| `connect` | `$$connect^VSLIO(host, port, timeout)` | Open an outbound TCP connection; return the device handle, else 0. |
| `connectTls` | `$$connectTls^VSLIO(host, port, timeout, config)` | UNIMPLEMENTED — raises, never opens plaintext. |
| `lastError` | `$$lastError^VSLIO()` | The last VSLIO error message (e.g. the TLS-gap remediation). |
| `read` | `$$read^VSLIO(id, maxlen, timeout, buf)` | Raw-read up to maxlen bytes from a handle. |
| `tlsAvailable` | `$$tlsAvailable^VSLIO()` | 0 — VSLIO has no wired TLS (engine TLS infra + XU*8.0*787 absent). |
| `tlsHelp` | `$$tlsHelp^VSLIO()` | Human-readable remediation for the TLS gap (diagnostics/logs). |
| `write` | `$$write^VSLIO(id, buf)` | Raw-write `buf` to a connected handle. |

### `$$close^VSLIO(id)`

Close an outbound connection opened by $$connect.

**Parameters**

- `id` _(string)_ — a handle from $$connect (the device)

**Returns** _bool_ — 1 (idempotent)

### `$$connect^VSLIO(host, port, timeout)`

Open an outbound TCP connection; return the device handle, else 0.

**Parameters**

- `host` _(string)_ — host/IP to connect to (IPADDRESS)
- `port` _(numeric)_ — remote TCP port (SOCKET)
- `timeout` _(numeric)_ — open timeout in seconds (default 10)

**Returns** _string_ — the opened device (handle) on POP=0, else 0

### `$$connectTls^VSLIO(host, port, timeout, config)`

UNIMPLEMENTED — raises, never opens plaintext.

**Parameters**

- `host` _(string)_ — host/IP (ignored — not implemented)
- `port` _(numeric)_ — TCP port (ignored — not implemented)
- `timeout` _(numeric)_ — seconds (ignored — not implemented)
- `config` _(string)_ — named TLS config (ignored — not implemented)

**Returns** _string_ — never returns a handle; always raises

**Raises**

- `U-VSLIO-NOTLS` — TLS not wired (known gap; see $$tlsHelp)

### `$$lastError^VSLIO()`

The last VSLIO error message (e.g. the TLS-gap remediation).

**Returns** _string_ — ^TMP($job,"vslio","err"), or "" if none

### `$$read^VSLIO(id, maxlen, timeout, buf)`

Raw-read up to maxlen bytes from a handle.

**Parameters**

- `id` _(string)_ — a handle from $$connect (the device)
- `maxlen` _(numeric)_ — maximum bytes to read
- `timeout` _(numeric)_ — seconds to wait for data
- `buf` _(string)_ — by-ref; receives the bytes read

**Returns** _numeric_ — bytes read (0 on timeout/EOF)

### `$$tlsAvailable^VSLIO()`

0 — VSLIO has no wired TLS (engine TLS infra + XU*8.0*787 absent).

**Returns** _bool_ — always 0 today: raw plaintext only (a known, tracked gap)

### `$$tlsHelp^VSLIO()`

Human-readable remediation for the TLS gap (diagnostics/logs).

**Returns** _string_ — multi-line: why there is no TLS + how to remedy

### `$$write^VSLIO(id, buf)`

Raw-write `buf` to a connected handle.

**Parameters**

- `id` _(string)_ — a handle from $$connect (the device)
- `buf` _(string)_ — bytes to write (raw, no delimiter)

**Returns** _bool_ — 1 on success

<!-- END GENERATED API REFERENCE -->
