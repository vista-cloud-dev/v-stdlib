# v-stdlib — canonical patterns

A copy-paste-ready idiom library for the most frequent v-stdlib
(`VSL*`) tasks. Each pattern is a short M block that runs once the named
symbols are on the routine path. Patterns assume the calling code lives
at `routine indent` (one tab / 8 spaces) per the modern-pythonic style;
keep that indent when pasting.

v-stdlib is **layer v** (VistA-specific): a `VSL*` routine MAY call an
`STD*` routine, never the reverse (the m/v waterline). For the
engine-neutral primitives (JSON, base64, crypto, assertions) reach for
the `m-stdlib` skill instead.

This file is the high-frequency-task catalogue, not the exhaustive
reference — `manifest-index.md` carries the full per-label list.

---

## XPAR config read/write — VSLCFG

The faithful VistA binding of the flat key→value config seam, over
Kernel Toolkit's Parameter Tools (XPAR) at the SYS (system) entity.

```m
set greeting=$$get^VSLCFG("VPNG GREETING","hello")   ; value, else default
do set^VSLCFG("VPNG GREETING","howdy")               ; write at SYS scope
```

`$$get` returns `default` when the parameter is unset; `do set` files
the value via `EN^XPAR`. XPAR is a Supported API (ICR #2263).

---

## Security-key & identity checks — VSLSEC

Authorization over Kernel's `^XUSEC` plus identity resolution against
NEW PERSON (#200).

```m
if '$$hasKey^VSLSEC("XUPROG") write "not a programmer",! quit   ; key held?
set duz=$$duz^VSLSEC()                  ; ambient principal (+$GET(DUZ))
set name=$$user^VSLSEC(duz)             ; #200 NAME for a DUZ
set ien=$$bySecid^VSLSEC(secid)         ; #200 IEN for a SecID (XUPS PERSONQUERY)
```

A malformed call (empty key/SecID) raises `,U-VSL-SEC-ARG,`; a normal
"key not held" is a clean `0`, never a raise. `$$lastError^VSLSEC()`
carries the detail after a raise.

---

## FileMan record store — VSLFS

The VistA database adapter over the FileMan DBS API (DIQ/DIE). Read,
write, existence, delete — all by `(file,iens,field)`.

```m
if $$exists^VSLFS(2,"1,") write $$get^VSLFS(2,"1,",.01,"?"),!   ; .01 of #2 record 1
set iens=$$set^VSLFS(file,iens,field,value)                      ; FILE^DIE; returns IENS
do kill^VSLFS(file,iens)                                         ; delete the record
```

A FileMan `DIERR` maps to `,U-VSL-FS-DIERR,`; `$$lastError^VSLFS()`
exposes the composed FileMan detail.

---

## Traffic tap — VSLTAP / VSLRPCTAP / VSLRPCWRAP

The non-interference RPC/HL7 tap. The broker-dispatch wrap
(`VSLRPCWRAP`) is the only splice into national code; everything below
it is fault-fenced and bounded so a tap fault can never perturb the
captured call.

```m
; The two side-calls the patched CALLP^XWBBRK invokes (req before, resp after):
do req^VSLRPCWRAP()      ; emit a dir=req record for EVERY RPC (incl. denied)
do resp^VSLRPCWRAP()     ; emit a dir=resp record on the dispatch-success path

; Gate + capture from your own producer:
if $$captureOn^VSLTAP() do teeRec^VSLTAP(.rec)    ; gated, fenced, bounded append
```

`$$captureOn` is the always-on ring gate (armed ∧ not auto-disabled);
`$$enabled` is the stricter egress gate (capture-on ∧ a sink present).
Never call `write1`/`append` directly — `tee`/`teeRec` own the fence.

---

## S3 egress — VSLS3

Drain the in-memory ring to S3 (or an S3-equivalent) as one batched
LDJSON object, then trim what shipped. Envelopes are schema-v1.

```m
new ctx,res
do  set ctx=$$ctx^VSLS3(.ctx,.opt)         ; creds + endpoint from the ^VSLTAP config seam
if $$drain^VSLS3(.res) do drainTo^VSLTAP(res("last"))   ; ship batch, then trim shipped prefix
```

`$$envelope^VSLS3(.rec,.opt)` frames one record; `$$key^VSLS3` builds
the `traffic/<station>/<proto>/Y/M/D/<seq>` object key. The actual
HTTP PUT/GET goes through `STDS3` (m-stdlib) — VSLS3 owns only the
VistA-side framing + config.

---

## TaskMan persistent listener — VSLTASK

Headless-queue a self-restarting listener through Kernel TaskMan
(`^%ZTLOAD`), no device attached.

```m
set ztsk=$$schedule^VSLTASK("RUN^MYLISTENER","my listener",when)  ; queue, returns task#
if $$persist^VSLTASK(ztsk) write "will self-restart",!            ; survive a node restart
if $$stop^VSLTASK() quit                                          ; cooperative stop check
```

A malformed call raises `,U-VSL-TASK-ARG,`; a queue failure
`,U-VSL-TASK-QUEUE,`. `$$running^VSLTASK()` probes the scheduler
heartbeat.

---

## Audit sink — VSLLOG

File one audit record into a FileMan audit file (the S3 audit seam).

```m
set iens=$$write^VSLLOG(file,"login","user=alice ip=1.2.3.4")  ; returns IENS, else raises
write $$read^VSLLOG(file,iens),!                                ; read the stored .01 line
```

A FileMan failure maps to `,U-VSL-LOG-WRITE,`; `$$lastError^VSLLOG()`
carries the detail.
