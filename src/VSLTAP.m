VSLTAP	; v-stdlib — non-interference traffic-tap core (the safety gate).
	;
	; Phase 2 / M1 of the RPC+HL7 -> S3 traffic tap (spec §6/§4.1). VSLTAP is the
	; load-bearing capture core everything downstream waits behind. Its whole job
	; is to be INVISIBLE to the clinical RPC flow it observes: a bounded, rolling
	; ^XTMP ring filled by an irreducible memory-copy append. Post-FU-9 the gates are
	; SPLIT: the ring CAPTURES whenever armed and not auto-failed-over (always-on,
	; `$$captureOn`), and only EGRESS is consumer/sink-gated (`$$enabled`); it is fenced
	; so any fault self-disables instead of touching the caller, and watched so ANY
	; interference signal flips the tap OFF automatically (fail-safe-OFF).
	;
	; *** Layer: v (above the m/v waterline). It touches ^XTMP (Kernel's SAC-
	; sanctioned scratch global) and consumes `m` utilities DOWN (STDDATE for the
	; FileMan purge-date); it never inverts the dependency. The egress/VistA
	; bindings (XPAR config source, VSLRPC chokepoint, Kernel XQ82 purge schedule)
	; are SEAMS, not Phase-2 dependencies — so the gate runs on a BARE engine with
	; no VistA and no S3 (kickoff). Config/state ride in ^VSLTAP (small control
	; state); the rolling capture cache rides in ^XTMP("VSLTAP",…) (the auto-
	; purged scratch global, §4.1.1 — no FileMan file).
	;
	; Capture buffer (the rolling "flight recorder", §4.1, Option A / D-10):
	;   ^XTMP("VSLTAP",0)            purgedate^createdate^description (Kernel XQ82)
	;   ^XTMP("VSLTAP","head")       highest written seq
	;   ^XTMP("VSLTAP","tail")       (lowest-retained seq) - 1
	;   ^XTMP("VSLTAP","data",seq)   the verbatim record (no transform)
	;
	; Control state (^VSLTAP — VSL namespace):
	;   ^VSLTAP("cfg",key)           mode/consumer/alwayson/cap/maxbytes/latbound/…
	;   ^VSLTAP("disabled")          auto-failover reason, else absent
	;   ^VSLTAP("hb")                liveness heartbeat ($H)
	;   ^VSLTAP("_offwindows")       count; (,n)=open^reason^close (explicit, never silent)
	;   ^VSLTAP("hl",…)              health counters/samples (VSLTAPHL)
	;   ^VSLTAP("fc","last")         last fidelity manifest line (VSLTAPFC persist)
	;
	; Public API:
	;   $$captureOn^VSLTAP()         1 iff the ring should capture now (always-on; FU-9)
	;   $$enabled^VSLTAP()           1 iff egress should run now (capture-on + consumer)
	;   $$append^VSLTAP(rec)         gated memory-copy append -> 1 captured / 0 not
	;   $$tee^VSLTAP(rec)            fault-fenced $$append (used by VSLRPCTAP)
	;   $$appendRec^VSLTAP(.rec)     gated append of a RICH record (cache layout v2; FU-5)
	;   $$teeRec^VSLTAP(.rec)        fault-fenced $$appendRec (used by the FU-5 wrap)
	;   $$hdr^VSLTAP(seq,.out)       parse the v2 header at seq -> out(field); 1 iff v2
	;   $$isV2^VSLTAP(seq) / $$chunk^VSLTAP(seq,i)   v2 record classify / payload chunk
	;   $$size^VSLTAP() / $$head() / $$tail() / $$read(seq) / $$present(seq)   ring inspection
	;   $$state^VSLTAP()             OFF | ARMED-IDLE | ACTIVE | AUTO-DISABLED | UNHEALTHY
	;   $$disabled^VSLTAP()          auto-failover reason or ""
	;   do arm() / off() / setConsumer(b) / setAlwaysOn(b)   operator/gate controls
	;   do disable(reason) / rearm()  auto-failover OFF / re-arm (records _offwindows)
	;   do heartbeat() / $$healthy()  liveness
	;   do purgeNode()               write the Kernel auto-purge node
	;   $$cfg(key,default)           read a config knob (consumed by VSLTAPHL)
	;   $$offWindows(.out)           recorded off-windows -> count
	;
	quit
	;
	; ---------- config ----------
	;
cfg(key,default)	; Read a config knob from ^VSLTAP("cfg",key), else `default`.
	; doc: @param key      string  config key (mode/consumer/alwayson/cap/maxbytes/latbound/hbstale/retain)
	; doc: @param default  string  value when unset
	; doc: @returns        string  the configured value or the default
	quit $get(^VSLTAP("cfg",key),default)
	;
arm()	; Operator: arm the tap (kill-switch ON) and clear any prior auto-disable.
	set ^VSLTAP("cfg","mode")="armed"
	kill ^VSLTAP("disabled")
	quit
	;
off()	; Operator: kill-switch OFF (state OFF; capture cannot run).
	set ^VSLTAP("cfg","mode")="off"
	quit
	;
setConsumer(present)	; Set the consumer-presence flag (D-5): no consumer -> egress/capture OFF.
	set ^VSLTAP("cfg","consumer")=+$get(present)
	quit
	;
setAlwaysOn(flag)	; LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture.
	; doc: The ring is ALWAYS-ON by default now ($$captureOn), so this opt-in is a no-op
	; doc: for gating. The cfg key is still written/readable so existing callers (e.g. the
	; doc: v-web console display) keep resolving; remove once consumers migrate.
	set ^VSLTAP("cfg","alwayson")=+$get(flag)
	quit
	;
	; ---------- the install-time XPAR -> cfg seed (self-configuring install) ----------
	;
seed()	; Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install).
	; doc: The KIDS install creates the tap params (VSLTAPBO $$params); the hot-path
	; doc: gate ($$cfg) and the VSLS3 ctx seam read ^VSLTAP("cfg",…), NOT XPAR (no
	; doc: XPAR/FileMan read on the capture path). seed bridges the two: it copies
	; doc: each set param into its cfg key once, at install/configure time. The
	; doc: fidelity cadence is read from XPAR directly (VSLTAPRUN), so it is not
	; doc: mirrored here. $text(GET^XPAR)-guarded -> a bare engine is a clean no-op.
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	new $etrap,map,n,i
	set $etrap="set $ecode="""" quit"
	if $text(GET^XPAR)="" quit
	set n=$$seedMap(.map)
	for i=1:1:n do seedOne(map(i,"param"),map(i,"cfg"))
	quit
	;
seedOne(param,cfgkey)	; (private) copy XPAR param `param` into ^VSLTAP("cfg",cfgkey) when it is set.
	new v
	set v=$$get^VSLCFG(param,"")
	if v'="" set ^VSLTAP("cfg",cfgkey)=v
	quit
	;
seedMap(map)	; Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count.
	; doc: @param map  array  OUT by-ref: map(i,"param")=XPAR name, map(i,"cfg")=cfg key
	; doc: @returns    numeric  the number of param->cfg mappings (the fidelity cadence is read direct)
	new n
	kill map
	set n=0
	do sm(.map,.n,"VSL TAP CAP","cap")
	do sm(.map,.n,"VSL TAP MAXBYTES","maxbytes")
	do sm(.map,.n,"VSL TAP HBSTALE","hbstale")
	do sm(.map,.n,"VSL TAP RETAIN","retain")
	do sm(.map,.n,"VSL TAP ALWAYSON","alwayson")
	do sm(.map,.n,"VSL S3 ENDPOINT","s3endpoint")
	do sm(.map,.n,"VSL S3 BUCKET","s3bucket")
	do sm(.map,.n,"VSL S3 REGION","s3region")
	do sm(.map,.n,"VSL S3 PREFIX","s3station")
	quit n
	;
sm(map,n,param,cfg)	; (private) append one param->cfg mapping row.
	set n=n+1
	set map(n,"param")=param,map(n,"cfg")=cfg
	quit
	;
	; ---------- the capture gate + the rolling ring ----------
	;
captureOn()	; FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled.
	; doc: @returns bool  the ALWAYS-ON capture gate. The ring records whenever the tap
	; doc: is armed and not auto-failed-over, INDEPENDENT of any consumer/sink — a down or
	; doc: absent sink pauses only EGRESS ($$enabled), never capture (the flight-recorder
	; doc: keeps a window of traffic ready for whenever a consumer attaches; it laps to
	; doc: drop_oldest only under sustained pressure). The ONLY things that stop the ring
	; doc: are the operator kill-switch ($$off) and auto-failover ($$disable) — fail-safe-OFF.
	if $$cfg("mode","off")'="armed" quit 0
	if $$disabled()'="" quit 0
	quit 1
	;
enabled()	; 1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5).
	; doc: @returns bool  the EGRESS gate. The drain ships and $$state reports ACTIVE only
	; doc: when this holds; with no consumer the ring still captures ($$captureOn) but the
	; doc: PUT pauses (the off-window is recorded, never silent). [FU-9 split the former
	; doc: single gate into capture (always-on) vs egress (consumer-gated).] The legacy
	; doc: `alwayson` flag is SUBSUMED — the ring is always-on by default now — and no
	; doc: longer gates anything (the setter/cfg are kept for backward compatibility).
	if '$$captureOn() quit 0
	if +$$cfg("consumer",0) quit 1
	quit 0
	;
append(rec)	; Gated, fault-fenced, bounded memory-copy append of a verbatim record.
	; doc: @param rec   string  the verbatim payload (no parse, no transform — D-1)
	; doc: @returns bool 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced
	; doc: The ONLY in-path op (besides the $G gate): one global SET + bounded trim.
	; doc: No LOCK, no serialize, no socket, no I/O, no block (§6.1). Self-fenced:
	; doc: ANY fault inside the write self-disables and returns 0 — never the caller.
	; doc: Flag-based $ETRAP (ISO, dual-engine; NEVER zgoto, the M4 resident-harness
	; doc: gotcha). The write runs in a DO-invoked frame (write1) so the trap's
	; doc: argument-less QUIT is legal — an arg-less QUIT trap fired in an extrinsic
	; doc: ($$) frame raises M17 NOTEXTRINSIC (per STDASSERT raises()).
	new ok,$etrap,wrote
	if '$$captureOn() quit 0
	set ok=1,wrote=0
	set $etrap="set ok=0,$ecode="""" quit"
	do write1(rec,.wrote)
	if ok quit wrote
	set $etrap=""
	do disable("fault")
	quit 0
	;
write1(rec,wrote)	; (private) the ring write, DO-invoked so the append fence's QUIT is legal.
	; doc: @param rec    string  the verbatim payload
	; doc: @param wrote  bool    by-ref; set 1 iff the record was appended
	new seq,cap
	; fault-injection seam — the §6.2 "injected deviation" exit-gate (b) lever.
	if +$$cfg("faultinject",0) set $ecode=",U-VSLTAP-INJECT,"
	; copy-cost guard (§6.2): a pathological mega-payload trips auto-failover OFF.
	if $length(rec)>+$$cfg("maxbytes",1000000) do disable("copycost") quit
	set cap=+$$cfg("cap",1000)
	; FU-8 (G-SEQ): allocate the sequence with an ATOMIC $INCREMENT (atomic on both YDB
	; and IRIS, no LOCK) — many concurrent broker handlers append to one ring, so the old
	; non-atomic read-then-write (`set seq=$get(head)+1` … `set head=seq`) RACED: two
	; handlers read the same head, both wrote `data,N`, one clobbered the other — a lost
	; record AND a duplicate seq (which breaks the §11 idempotent S3 key). $INCREMENT both
	; allocates a unique seq and advances head in one indivisible step. It sits AFTER
	; the maxbytes copy-cost guard above ON PURPOSE — a rejected mega-payload must not
	; burn a seq (which would leave a permanent hole the gap-safe drain stops at forever).
	set seq=$increment(^XTMP("VSLTAP","head"))
	set ^XTMP("VSLTAP","data",seq)=rec
	; FU-4 post-write fault-injection seam: fire AFTER the ring SET so the fence
	; property suite (VSLTAPFENCETST) proves the naked-reference restore even once
	; the tap has dirtied the caller's indicator (AC-1). Inert unless configured.
	if +$$cfg("faultinjectpost",0) set $ecode=",U-VSLTAP-INJECTPOST,"
	do trim(seq,cap)
	do record^VSLTAPHL(0,$length(rec),0)
	set wrote=1
	quit
	;
trim(seq,cap)	; (private) overwrite-oldest: drop entries until the ring holds at most `cap`.
	new t
	set t=+$get(^XTMP("VSLTAP","tail"))
	for  quit:(seq-t)'>cap  do dropOldest(.t)
	set ^XTMP("VSLTAP","tail")=t
	quit
	;
dropOldest(t)	; (private) drop the oldest retained entry and advance the tail cursor.
	set t=t+1
	kill ^XTMP("VSLTAP","data",t)
	quit
	;
tee(rec)	; The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced.
	; doc: @param rec   string  the verbatim payload
	; doc: @returns bool the $$append result (0 if gated or a fault was fenced)
	; doc: $$append is already self-fenced (a DO-framed $ETRAP that self-disables on
	; doc: any fault); tee is the stable adapter entry. Either leaves the caller's
	; doc: result / $ECODE / $T untouched.
	quit $$append(rec)
	;
	; ---------- cache layout v2: the rich capture record (FU-5 / FU-14 / FU-17) ----------
	;
	; The Phase-6 wrap (FU-5) at the active broker CALLP captures a STRUCTURED record,
	; not a flat string: a header node + payload chunk node(s) + (for a GLOBAL ARRAY
	; result) a single MERGE snapshot subtree (FU-17). The schema is frozen in
	; docs/design/s3tap-envelope-schema-lock.md (cache layout v2):
	;   ^XTMP("VSLTAP","data",seq)        = HEADER (^-pieces; no field may contain ^)
	;   ^XTMP("VSLTAP","data",seq,"p",i)  = payload chunk i (RAW bytes; i=1..chunk_count)
	;   ^XTMP("VSLTAP","data",seq,"hc",i) = per-chunk sha256 (FU-2 integrity)
	;   ^XTMP("VSLTAP","data",seq,"g")    = MERGE snapshot of a GLOBAL ARRAY result (FU-17)
	; The ring stores RAW payload bytes; the wire encoding (base64/raw) and the
	; expensive serialize/hash of a global subtree are deferred to the drain (off the
	; in-path, §6.1). `payload_encoding` in the header records the intended wire encoding.
	; The drain is dual-mode: a v2 record (a "p"/"g" child present) frames schema v1 from
	; the header; a legacy v1 string record ($$append) still ships as before.
	;
appendRec(rec)	; FU-5: gated, fault-fenced, bounded append of a RICH (cache layout v2) record.
	; doc: @param rec   array  by-ref record descriptor (dir/rpc/payload/gref/call_id/...; read-only)
	; doc: @returns bool 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced
	; doc: The v2 sibling of $$append — same self-disabling $ETRAP, same DO-framed write
	; doc: (write1rec) so the trap's arg-less QUIT is legal. The caller-state fence
	; doc: (naked-ref/$TEST) lives one level up in capture^VSLRPCTAP (FU-4).
	new ok,$etrap,wrote
	if '$$captureOn() quit 0
	set ok=1,wrote=0
	set $etrap="set ok=0,$ecode="""" quit"
	do write1rec(.rec,.wrote)
	if ok quit wrote
	set $etrap=""
	do disable("fault")
	quit 0
	;
teeRec(rec)	; The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced.
	; doc: @param rec   array  by-ref record descriptor
	; doc: @returns bool the $$appendRec result (0 if gated or a fault was fenced)
	quit $$appendRec(.rec)
	;
write1rec(rec,wrote)	; (private) write one cache-layout-v2 record, DO-invoked so the fence's QUIT is legal.
	; doc: @param rec    array  by-ref record descriptor (read-only)
	; doc: @param wrote  bool   by-ref; set 1 iff the record was appended
	new seq,cap,kind,gref,pl,wl,cc,hash,enc
	; fault-injection seam (mirrors write1) — the §6.2 exit-gate (b) lever.
	if +$$cfg("faultinject",0) set $ecode=",U-VSLTAP-INJECT,"
	set gref=$get(rec("gref"))
	set kind=$get(rec("result_kind"))
	if (gref'=""),(kind="") set kind="global"
	if (kind=""),($get(rec("dir"))="resp") set kind="scalar"
	set pl=$get(rec("payload"))
	set enc=$$cfg("payloadenc","raw")
	; copy-cost guard (§6.2): a pathological mega-payload trips auto-failover OFF.
	; (A GLOBAL ARRAY snapshot is a single MERGE; its drain-side ceiling is FU-2's concern.)
	if gref="",$length(pl)>+$$cfg("maxbytes",1000000) do disable("copycost") quit
	set cap=+$$cfg("cap",1000)
	; FU-8 (G-SEQ): allocate the seq with an ATOMIC $INCREMENT (after the copy-cost guard,
	; so a rejected mega-payload never burns a seq) — same rationale as write1.
	set seq=$increment(^XTMP("VSLTAP","head"))
	if gref'="" do
	. ; FU-17: ONE merge snapshot of the GLOBAL ARRAY result (snapshot before the broker's
	. ; SNDDATA^XWBRW:60 kill; the broker spares ^XTMP( roots, so this is collision-free).
	. ; The drain walks "g", serializes, chunks, and hashes — all off the in-path.
	. ; gref is a closed-root global ref the broker built (XWBP/XWBY), not external input;
	. ; the MERGE target is a fixed ^XTMP node — this indirection is the FU-17 snapshot, by design.
	. ; m-lint: disable-next-line=M-MOD-036
	. merge ^XTMP("VSLTAP","data",seq,"g")=@gref
	. ; guarantee a "g" node exists even for an empty result, so $$isV2 still classifies it.
	. if '$data(^XTMP("VSLTAP","data",seq,"g")) set ^XTMP("VSLTAP","data",seq,"g")=""
	. set wl=0,cc=0,hash=""
	else  do
	. set wl=$length(pl),cc=1
	. set ^XTMP("VSLTAP","data",seq,"p",1)=pl
	. set hash=$$sha256^STDCRYPTO(pl)
	. set ^XTMP("VSLTAP","data",seq,"hc",1)=hash
	set ^XTMP("VSLTAP","data",seq)=$$hdrLine(seq,.rec,kind,wl,cc,enc,hash)
	; FU-4 post-write fault-injection seam (mirrors write1) — proves the fence once dirtied.
	if +$$cfg("faultinjectpost",0) set $ecode=",U-VSLTAP-INJECTPOST,"
	do trim(seq,cap)
	do record^VSLTAPHL(0,wl,0)
	set wrote=1
	quit
	;
hdrLine(seq,rec,kind,wl,cc,enc,hash)	; (private) assemble the cache-layout-v2 ^-delimited header.
	; doc: The frozen 18-piece header (schema-lock §4); NO field may contain "^" (the
	; doc: payload — which can — lives in the "p"/"g" subtree, never the header).
	new dir,cid,eid,h
	set dir=$get(rec("dir"))
	set cid=$get(rec("call_id"))
	set eid=$select($get(rec("event_id"))'="":rec("event_id"),cid'="":cid_":"_dir,1:"")
	; schema_version^event_id^call_id^direction^protocol^rpc^result_kind^wire_len^
	; chunk_count^payload_encoding^duz^job^client^ts^tag^nam^denied^payload_sha256
	set h=1_"^"_eid_"^"_cid_"^"_dir
	set h=h_"^"_$get(rec("protocol"),"rpc")_"^"_$get(rec("rpc"))_"^"_kind
	set h=h_"^"_(+wl)_"^"_(+cc)_"^"_enc
	set h=h_"^"_$get(rec("duz"))_"^"_(+$get(rec("job")))_"^"_$get(rec("client"))
	set h=h_"^"_$get(rec("ts"),$horolog)
	set h=h_"^"_$get(rec("tag"))_"^"_$get(rec("nam"))
	set h=h_"^"_(+$get(rec("denied")))_"^"_hash
	quit h
	;
size()	; Current ring entry count (head - tail).
	quit +$get(^XTMP("VSLTAP","head"))-+$get(^XTMP("VSLTAP","tail"))
	;
head()	; Highest written seq (0 if empty).
	quit +$get(^XTMP("VSLTAP","head"))
	;
tail()	; (lowest-retained seq) - 1 (0 if empty).
	quit +$get(^XTMP("VSLTAP","tail"))
	;
read(seq)	; The verbatim record at `seq`, or "" if absent/overwritten.
	quit $get(^XTMP("VSLTAP","data",+$get(seq)))
	;
present(seq)	; 1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot.
	; doc: @returns bool  The drain ships only the CONTIGUOUS COMMITTED prefix using this:
	; doc: FU-8's atomic $INCREMENT advances head one statement BEFORE the data SET, so a
	; doc: concurrent always-on drain (FU-9) can momentarily see head ahead of an in-flight
	; doc: slot; stopping at the first absent node leaves that slot for the next tick rather
	; doc: than shipping "" and trimming a record that is about to land. `$$read` can't tell
	; doc: an absent slot from a legitimately-empty record ($get-> "" for both); this can.
	quit $data(^XTMP("VSLTAP","data",+$get(seq)))'=0
	;
isV2(seq)	; 1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present).
	; doc: A legacy v1 string record ($$append) has only the scalar data node — no child.
	new s
	set s=+$get(seq)
	quit ($data(^XTMP("VSLTAP","data",s,"p"))'=0)!($data(^XTMP("VSLTAP","data",s,"g"))'=0)
	;
hdr(seq,out)	; Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record.
	; doc: @param seq  numeric  the ring sequence
	; doc: @param out  array    OUT by-ref: the 18 header fields keyed by their schema-v1 names
	; doc: @returns    bool     1 iff `seq` is a v2 record (else `out` is killed, returns 0)
	new h,s
	kill out
	if '$$isV2(seq) quit 0
	set s=+$get(seq),h=$get(^XTMP("VSLTAP","data",s))
	set out("schema_version")=$piece(h,"^",1)
	set out("event_id")=$piece(h,"^",2)
	set out("call_id")=$piece(h,"^",3)
	set out("direction")=$piece(h,"^",4)
	set out("protocol")=$piece(h,"^",5)
	set out("rpc")=$piece(h,"^",6)
	set out("result_kind")=$piece(h,"^",7)
	set out("wire_len")=$piece(h,"^",8)
	set out("chunk_count")=$piece(h,"^",9)
	set out("payload_encoding")=$piece(h,"^",10)
	set out("duz")=$piece(h,"^",11)
	set out("job")=$piece(h,"^",12)
	set out("client")=$piece(h,"^",13)
	set out("ts")=$piece(h,"^",14)
	set out("tag")=$piece(h,"^",15)
	set out("nam")=$piece(h,"^",16)
	set out("denied")=$piece(h,"^",17)
	set out("payload_sha256")=$piece(h,"^",18)
	quit 1
	;
chunk(seq,i)	; The i-th RAW payload chunk of a v2 record ("" if absent).
	quit $get(^XTMP("VSLTAP","data",+$get(seq),"p",+$get(i)))
	;
drainTo(seq)	; Post-ship trim: drop retained entries up to and including `seq`, advance tail.
	; doc: @param seq  numeric  the highest shipped sequence (bounded to head)
	; doc: @returns    void     the drain self-KILLs shipped entries (spec §4.1.3)
	; doc: Called by the SEPARATE flush process (VSLS3 $$drain) AFTER a batch ships
	; doc: 200 — never from the RPC path. Idempotent; never advances past head.
	new t,h
	set h=+$get(^XTMP("VSLTAP","head"))
	if +$get(seq)>h set seq=h
	set t=+$get(^XTMP("VSLTAP","tail"))
	for  quit:t'<+$get(seq)  do dropOldest(.t)
	set ^XTMP("VSLTAP","tail")=t
	quit
	;
	; ---------- auto-failover + state machine ----------
	;
disable(reason)	; Auto-failover: disable the tap, record an off-window (explicit, never silent).
	; doc: @param reason  string  the interference signal (fault/copycost/latency/pressure)
	new n
	if $get(^VSLTAP("disabled"))'="" quit
	set ^VSLTAP("disabled")=reason
	set n=+$get(^VSLTAP("_offwindows"))+1
	set ^VSLTAP("_offwindows")=n
	set ^VSLTAP("_offwindows",n)=$horolog_"^"_reason_"^"
	quit
	;
disabled()	; The auto-failover reason, or "" if armed/clean.
	quit $get(^VSLTAP("disabled"))
	;
rearm()	; Re-arm after a clean cool-down (D-4): clear the disable + close the off-window.
	new n
	kill ^VSLTAP("disabled")
	set n=+$get(^VSLTAP("_offwindows"))
	if n,$piece($get(^VSLTAP("_offwindows",n)),"^",3)="" set $piece(^VSLTAP("_offwindows",n),"^",3)=$horolog
	quit
	;
offWindows(out)	; Populate out(1..N) with the recorded off-windows; return the count.
	; doc: @param out  array  by-ref; killed then filled with open^reason^close rows
	new n,i
	kill out
	set n=+$get(^VSLTAP("_offwindows"))
	for i=1:1:n set out(i)=$get(^VSLTAP("_offwindows",i))
	quit n
	;
state()	; The standby state-machine label (spec §8.1).
	; doc: @returns string OFF | AUTO-DISABLED | UNHEALTHY | ACTIVE | ARMED-IDLE
	if $$cfg("mode","off")'="armed" quit "OFF"
	if $$disabled()'="" quit "AUTO-DISABLED"
	if '$$healthy() quit "UNHEALTHY"
	if $$enabled() quit "ACTIVE"
	quit "ARMED-IDLE"
	;
	; ---------- liveness ----------
	;
heartbeat()	; Stamp the liveness heartbeat (the watchdog beats this every N seconds).
	set ^VSLTAP("hb")=$horolog
	quit
	;
healthy()	; 1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness).
	; doc: @returns bool  a stale/absent heartbeat -> 0 (UNHEALTHY) even with zero traffic
	new hb,age,now
	set hb=$get(^VSLTAP("hb"))
	if hb="" quit 0
	set now=$horolog
	set age=(($piece(now,",",1)-$piece(hb,",",1))*86400)+($piece(now,",",2)-$piece(hb,",",2))
	quit (age'>+$$cfg("hbstale",60))
	;
	; ---------- Kernel auto-purge node (the cache backstop) ----------
	;
purgeNode()	; Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it.
	; doc: The SAC ^XTMP convention (XU/krn_8_0_dg_xtmp_global_ug): a ,0) node of
	; doc: FileMan internal dates lets `XQ XUTL $J NODES` auto-purge the cache. No
	; doc: FileMan file (§4.1.1). Scheduling the option is an install-time seam.
	new td,ret
	set ret=+$$cfg("retain",2)
	set td=+$horolog
	set ^XTMP("VSLTAP",0)=$$fmDate(td+ret)_"^"_$$fmDate(td)_"^VSL RPC traffic-tap rolling cache"
	quit
	;
fmDate(hday)	; ($H day-count) -> FileMan internal date (YYYMMDD, YYY=year-1700).
	new z,y,m,d
	set z=hday-47117
	do civilFromDays^STDDATE(z,.y,.m,.d)
	quit ((y-1700)*10000)+(m*100)+d
