# v-stdlib — manifest index

v-stdlib unversioned; 17 modules; 125 public labels.

Generated from `dist/vsl-manifest.json`. One entry per module
with every public label: signature on the left, synopsis on the
right. For full per-label detail (params, returns, raises,
examples, source location), read the manifest entry directly.

## `VSLBLD`

the VSL KIDS base build definition + env-check binding (packaging seam).

- `$$envCheck^VSLBLD(facts)` — The environment facts (engine/version/Kernel/TLS) via the self-contained VSLENV (v->v).
- `$$lastError^VSLBLD()` — The last VSLBLD error message (the composed malformed-call detail).
- `$$manifest^VSLBLD(out)` — Fill out() with the VSL base's routines, its Required Build and patch identity; return the routine count.
- `$$requireBase^VSLBLD(build)` — 1 iff KIDS build `build` is installed on this system (the R6 version-skew check).

_raises: `U-VSL-BLD-ARG`_

## `VSLCFG`

VistA configuration adapter over XPAR (Parameter Tools).

- `$$get^VSLCFG(key, default)` — Read parameter `key` at the SYS entity; return `default` when unset.
- `do set^VSLCFG(key, value)` — Set parameter `key` to `value` at the SYS entity.

## `VSLENV`

the VSL KIDS environment-check routine (the XPDENV hook).

- `do abort^VSLENV()` — (private) a genuine showstopper — Kernel (XU) is not present; abort the install.
- `$$check^VSLENV(facts)` — Fill facts(engine,version,kernel,tls) from intrinsics + resident Kernel; return 1.
- `$$kernelVer^VSLENV()` — (private) the Kernel (#9.4 XU) current version, "" if unavailable.
- `$$tlsConfig^VSLENV()` — (private) the DEFAULT TLS SERVER CONFIG Kernel System Parameter (presence), "" if unset.

## `VSLFS`

VistA FileMan storage adapter (FileMan DBS record store).

- `$$exists^VSLFS(file, iens)` — Return 1 iff record (file,iens) exists (its .01 reads without a DIERR).
- `$$get^VSLFS(file, iens, field, default)` — Read (file,iens,field) via $$GET1^DIQ; return value, else `default`.
- `$$kill^VSLFS(file, iens)` — Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1.
- `$$lastError^VSLFS()` — The last VSLFS error message (the composed FileMan DIERR detail).
- `$$set^VSLFS(file, iens, field, value)` — File `value` into (file,iens,field); return the resolved IENS, else raise.

_raises: `U-VSL-FS-DIERR`_

## `VSLHL7TAP`

HL7 store-tail adapter (decoupled, zero in-line).

- `$$cursor^VSLHL7TAP(store)` — The persisted high-water IEN for a store ("772" | "778"); 0 if unset.
- `$$readHLO^VSLHL7TAP(ien)` — Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body).
- `$$readLegacy^VSLHL7TAP(ien)` — Reassemble the verbatim CR-delimited message for #772 entry `ien`.
- `do resetCursors^VSLHL7TAP()` — Clear both cursors (re-tail from the beginning of each store).
- `do setCursor^VSLHL7TAP(store, ien)` — Persist the high-water IEN for a store.
- `do tail^VSLHL7TAP()` — Tail both HL7 stores once: ship every newly-persisted message into the ring.
- `do tailHLO^VSLHL7TAP()` — Tail #778/#777 forward from its cursor, teeing each new verbatim message.
- `do tailLegacy^VSLHL7TAP()` — Tail #772 forward from its cursor, teeing each new verbatim message.

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

VistA FileMan audit-sink adapter (the S3 audit seam).

- `$$lastError^VSLLOG()` — The last VSLLOG error message (the composed FileMan detail).
- `$$read^VSLLOG(file, iens)` — Read the audit line stored at (file,iens) .01, else "".
- `do write^VSLLOG(file, event, detail)` — File one audit record into `file`; return the resolved IENS, else raise.

_raises: `U-VSL-LOG-WRITE`_

## `VSLRPCTAP`

RPC tap adapter at the VSLRPC chokepoint (the fenced tee).

- `$$callId^VSLRPCTAP(station, ctr)` — Build a correlation call_id = station "-" $J "-" ctr (schema-lock §2).
- `do capture^VSLRPCTAP(rec)` — Fenced fire-and-forget tee of one RPC record (cache layout v2) into the rolling ring.
- `$$nakedRef^VSLRPCTAP()` — (private) the caller's last global reference, dual-engine. "" at job start.
- `do work^VSLRPCTAP(rec)` — (private) the global-touching side, DO-framed so a fault can never escape the boundary.

## `VSLRPCWRAP`

the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK).

- `do ctx^VSLRPCWRAP(rec)` — (private) FU-18 context read at the wrap depth (process scope; ancestor EN^XWBTCPC).
- `$$params^VSLRPCWRAP()` — (private) join the broker's decoded input params XWB(3,"P",*) verbatim (no typing — §9).
- `do req^VSLRPCWRAP()` — Request side-call: emit a dir=req record for EVERY RPC (incl. denied/errored).
- `do reqWork^VSLRPCWRAP()` — (private) DO-framed: gate, build the dir=req rec from broker vars, tee it.
- `do resp^VSLRPCWRAP()` — Result side-call: emit a dir=resp record on the dispatch-success path.
- `do result^VSLRPCWRAP(rec)` — (private) classify the result by XWBPTYPE (FU-16(c)) — scalar payload or a snapshot ref.

## `VSLS3`

S3 egress sink: LDJSON envelope + the §11 bucket layout.

- `$$ctx^VSLS3(ctx, opt)` — Build the S3 credential ctx + opt(endpoint) from the ^VSLTAP config seam.
- `$$drain^VSLS3(res)` — Flush the ^XTMP ring to S3 as one LDJSON batch, then trim the shipped entries.
- `$$envelope^VSLS3(rec, opt)` — Frame one captured record as a single schema-v1 LDJSON line.
- `$$fidelityKey^VSLS3(station, ymd)` — The per-day _fidelity manifest key (periodic VSLTAPFC results, §11).
- `$$gSerialize^VSLS3(seq)` — Serialize a v2 GLOBAL-ARRAY MERGE snapshot (^...,"g") to a deterministic, lossless blob.
- `$$key^VSLS3(station, proto, seq, ymd)` — The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson.
- `$$list^VSLS3(ctx, bucket, prefix, opt, listing)` — LIST object keys under `prefix` via STDS3 listObjectsV2.
- `$$offWindowsKey^VSLS3(station, ymd)` — The per-day _offwindows manifest key (explicit tap-off windows, §11).
- `$$readback^VSLS3(ctx, bucket, key, opt, resp)` — GET one object back from S3 / the S3-equivalent via STDS3.
- `do resolveRec^VSLS3(seq, station, proto, erec)` — Build the schema-v1 field array for the record at `seq` (dual-mode: v2 header / v1 legacy).
- `$$ship^VSLS3(ctx, bucket, key, body, opt, resp)` — PUT one object to S3 / the S3-equivalent via STDS3.

## `VSLSEC`

VistA identity/authorization adapter (Kernel).

- `$$bySecid^VSLSEC(secid)` — The #200 IEN for a SecID via EN1^XUPSQRY (RPC XUPS PERSONQUERY), else "".
- `$$duz^VSLSEC()` — The ambient principal — +$GET(DUZ), the caller's NEW PERSON (#200) IEN.
- `$$hasKey^VSLSEC(key, duz)` — 1 iff `duz` (default: the ambient DUZ) holds security key `key`.
- `$$lastError^VSLSEC()` — The last VSLSEC error message (the composed malformed-call detail).
- `do user^VSLSEC(duz)` — The #200 NAME for `duz` (default: the ambient DUZ), resolved via VSLFS.

_raises: `U-VSL-SEC-ARG`_

## `VSLTAP`

non-interference traffic-tap core (the safety gate).

- `$$append^VSLTAP(rec)` — Gated, fault-fenced, bounded memory-copy append of a verbatim record.
- `$$appendRec^VSLTAP(rec)` — FU-5: gated, fault-fenced, bounded append of a RICH (cache layout v2) record.
- `do arm^VSLTAP()` — Operator: arm the tap (kill-switch ON) and clear any prior auto-disable.
- `$$captureOn^VSLTAP()` — FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled.
- `$$cfg^VSLTAP(key, default)` — Read a config knob from ^VSLTAP("cfg",key), else `default`.
- `$$chunk^VSLTAP(seq, i)` — The i-th RAW payload chunk of a v2 record ("" if absent).
- `do disable^VSLTAP(reason)` — Auto-failover: disable the tap, record an off-window (explicit, never silent).
- `$$disabled^VSLTAP()` — The auto-failover reason, or "" if armed/clean.
- `do drainTo^VSLTAP(seq)` — Post-ship trim: drop retained entries up to and including `seq`, advance tail.
- `$$enabled^VSLTAP()` — 1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5).
- `$$hdr^VSLTAP(seq, out)` — Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record.
- `$$head^VSLTAP()` — Highest written seq (0 if empty).
- `$$healthy^VSLTAP()` — 1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness).
- `do heartbeat^VSLTAP()` — Stamp the liveness heartbeat (the watchdog beats this every N seconds).
- `$$isV2^VSLTAP(seq)` — 1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present).
- `do off^VSLTAP()` — Operator: kill-switch OFF (state OFF; capture cannot run).
- `$$offWindows^VSLTAP(out)` — Populate out(1..N) with the recorded off-windows; return the count.
- `$$present^VSLTAP(seq)` — 1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot.
- `do purgeNode^VSLTAP()` — Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it.
- `$$read^VSLTAP(seq)` — The verbatim record at `seq`, or "" if absent/overwritten.
- `do rearm^VSLTAP()` — Re-arm after a clean cool-down (D-4): clear the disable + close the off-window.
- `do seed^VSLTAP()` — Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install).
- `$$seedMap^VSLTAP(map)` — Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count.
- `do setAlwaysOn^VSLTAP(flag)` — LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture.
- `do setConsumer^VSLTAP(present)` — Set the consumer-presence flag (D-5): no consumer -> egress/capture OFF.
- `$$size^VSLTAP()` — Current ring entry count (head - tail).
- `$$state^VSLTAP()` — The standby state-machine label (spec §8.1).
- `$$tail^VSLTAP()` — (lowest-retained seq) - 1 (0 if empty).
- `$$tee^VSLTAP(rec)` — The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced.
- `$$teeRec^VSLTAP(rec)` — The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced.

## `VSLTAPBO`

traffic-tap back-out / verify-clean (the G-UNINST gate).

- `do backout^VSLTAPBO()` — Full back-out: dequeue tasks, drop the XPAR params, kill the state. Idempotent.
- `do cleanParams^VSLTAPBO()` — Drop every tap XPAR param: clear the SYS instance, delete the #8989.51 definition.
- `do cleanState^VSLTAPBO()` — Kill the rolling capture cache and ALL VSL control state.
- `do cleanTasks^VSLTAPBO()` — Dequeue every recorded flush/fidelity TaskMan job (read BEFORE cleanState).
- `do delParam^VSLTAPBO(name)` — (private) clear the SYS-level instance, then delete the #8989.51 definition record.
- `do dequeue^VSLTAPBO(ztsk)` — (private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced.
- `$$params^VSLTAPBO(out)` — Fill out(1..N) with the tap's XPAR #8989.51 param names; return N.
- `$$paramsResidue^VSLTAPBO(detail)` — (private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0).
- `$$verifyClean^VSLTAPBO(detail)` — 1 iff no tap residue remains across all layers; detail() names any survivor.

## `VSLTAPFC`

fidelity comparator: byte-equality proof, not assertion.

- `$$drops^VSLTAPFC(envs, res)` — Classify the loss taxonomy by grouping the shipped envelopes on call_id (FU-15).
- `$$lastFidelity^VSLTAPFC()` — The last persisted _fidelity manifest line, or "" when no run has run yet.
- `$$manifest^VSLTAPFC(res, ts)` — Serialise a fidelity run to a single JSON manifest line (the _fidelity object).
- `$$matches^VSLTAPFC(line, source)` — 1 iff the decoded payload byte-equals `source` AND the hash anchor is intact.
- `$$payloadOf^VSLTAPFC(line)` — Decode one LDJSON envelope line back to the verbatim captured bytes.
- `do persist^VSLTAPFC(res, ts)` — Store the last fidelity run so the console can read it (no live run on request).
- `$$reconcile^VSLTAPFC(corpus, envs, res)` — Reconcile a generated corpus against the read-back envelopes, by sequence.
- `$$verify^VSLTAPFC(line)` — 1 iff the envelope's payload re-hashes to the sha256 anchor it carries (§7).

## `VSLTAPHL`

tap health instrument + standby readiness (the watchdog).

- `$$abcheck^VSLTAPHL(base, tapped)` — 1 iff (tapped - base) exceeds the pre-registered D-7 latency bound.
- `$$canary^VSLTAPHL()` — Synthetic byte-exact round-trip of a tagged record through ^XTMP — touches no real RPC.
- `$$pctl^VSLTAPHL(p)` — The p-th percentile (nearest-rank) of the latency-sample window; 0 if none.
- `$$ready^VSLTAPHL()` — Standby readiness probe: 1 iff a gated/idle tap COULD capture if a consumer appeared.
- `do record^VSLTAPHL(us, bytes, denied)` — Record one capture sample: a denial, or a write (+bytes, +optional latency).
- `do watchLatency^VSLTAPHL(base, tapped)` — Trip auto-failover OFF when the tapped-vs-baseline delta breaches the bound.

## `VSLTAPRUN`

the periodic fidelity-run task (closes the console loop).

- `$$cadence^VSLTAPRUN()` — The fidelity-run period in seconds: XPAR VSL TAP FIDELITY CADENCE, default 3600.
- `$$fidelityNow^VSLTAPRUN()` — Sample recently-shipped objects, integrity-verify each, persist the result -> matched count.
- `do nextKey^VSLTAPRUN(k, seen, listing, ctx, bucket, opt, res)` — (private) step to the previous listed subscript; verify its object if it's a real key.
- `$$reconcilePersist^VSLTAPRUN(corpus, envs)` — Reconcile the corpus vs the read-back envelopes, persist the result, return ok.
- `do run^VSLTAPRUN()` — The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan).
- `$$schedule^VSLTAPRUN()` — Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it.

## `VSLTASK`

VistA TaskMan persistent-listener adapter (the process seam).

- `$$lastError^VSLTASK()` — The last VSLTASK error message (the composed malformed-call / fault detail).
- `$$persist^VSLTASK(ztsk)` — Mark queued task `ztsk` persistent so TaskMan self-restarts it on a lock drop.
- `$$queue^VSLTASK(entry, desc, when)` — (private) headless ^%ZTLOAD queue (no device); return the task number, else 0.
- `$$running^VSLTASK()` — 1 iff the TaskMan scheduler is live (its ^%ZTSCH("RUN") heartbeat is fresh).
- `$$schedule^VSLTASK(entry, desc, when)` — Headless-queue a persistent listener at `entry`; return its task number.
- `$$stop^VSLTASK()` — 1 iff a stop has been requested of the currently-running task (cooperative stop).

_raises: `U-VSL-TASK-ARG`, `U-VSL-TASK-QUEUE`_

