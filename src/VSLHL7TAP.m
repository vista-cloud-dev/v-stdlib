VSLHL7TAP	; v-stdlib — HL7 store-tail adapter (decoupled, zero in-line).
	; doc: @exrun bare
	;
	; Phase 3 / M2 of the RPC+HL7 -> S3 traffic tap (spec §4, D-3). The HL7 half of
	; the tap. Unlike VSLRPCTAP (an in-line tee BESIDE the ephemeral RPC runner),
	; the HL7 traffic is ALREADY persisted by the HL7 package, so VSLHL7TAP is a
	; passive STORE-TAILER: a separate flush process (VSLTASK, like VSLS3 $$drain)
	; reads new entries forward from a saved cursor and tees each verbatim message
	; into the same VSLTAP ring. Non-interference is STRUCTURAL — it only READS the
	; stores the HL7 send/receive path already wrote, adding nothing to that path.
	;
	; *** G-HL7HOOK resolved by a LIVE probe of vehu (YDB-VistA) 2026-06-20 + the
	; #772/#778/#777 DD: VistA keeps TWO parallel HL7 message stores and both can
	; carry live traffic, so the tail covers both:
	;
	;   legacy HL7 (#772, ^HL(772,) — package-managed, NOT a FileMan WP field:
	;     ^HL(772,IEN,0)            = fmDateTime^^^DIR^^MSGID^^IEN^STATUS^...
	;     ^HL(772,IEN,"IN",0)       = WP header ^^lastseq^count^date^
	;     ^HL(772,IEN,"IN",seq,0)   = one verbatim HL7 segment per node (seq 1..N)
	;   HLO (#778 ^HLB / #777 ^HLA):
	;     ^HLB(IEN,0)               = MSGID^bodyIEN^^DIR^LINK   (.02 -> #777)
	;     ^HLB(IEN,1) / ^HLB(IEN,2) = MSH components 1-6 / 7-end (rebuilt header)
	;     ^HLA(bodyIEN,1,seq,0)     = one verbatim body segment (MSH excluded)
	;
	; The reliable tail cursor is the LAST PRESENT numeric IEN ($ORDER), NOT the
	; file 0-node's 3rd piece — the probe found ^HL(772,0) piece-3 stale (4589) while
	; the live entries keyed at ~2.23M; HLO assigns IENs from ^HLC, not a 0-node +1.
	; Non-numeric top-level subscripts (the B/C/AF/AI cross-references) are skipped.
	;
	; Layer: v. Consumes the VSLTAP core (v->v, consumer-gated + fault-fenced via
	; $$tee^VSLTAP); the engine seam stays in VSLTAP. Cursors ride in ^VSLTAP.
	;
	; Public API:
	;   do tail()              — tail BOTH stores once (gated; ship every new message)
	;   do tailLegacy()        — tail #772 forward from its cursor
	;   do tailHLO()           — tail #778/#777 forward from its cursor
	;   $$readLegacy(ien)      — verbatim reassembly of a #772 entry ("" if purged)
	;   $$readHLO(ien)         — verbatim reassembly of a #778/#777 entry
	;   $$cursor(store)        — the persisted high-water IEN ("772" | "778")
	;   do setCursor(store,ien) / resetCursors()   — cursor controls
	;
	quit
	;
	; ---------- the tail (gated, fenced, forward-only) ----------
	;
tail()	; Tail both HL7 stores once: ship every newly-persisted message into the ring.
	; doc: @returns void  consumer-gated at the top (no consumer -> no tail, cursors
	; doc: frozen so a re-arm catches up); each store tail is independently fenced.
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772),^HLB,^HLA  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HL(772,10,0)="3170627.01^^^O^^L1^^10^D",^HL(772,10,"IN",1,0)="MSH|leg",^HL(772,10,"IN",0)="^^1^1^3170627^"  set ^HLB(3,0)="H1^200^^O^link",^HLB(3,1)="MSH|^~\&|",^HLB(3,2)="|ADT",^HLA(200,1,1,0)="EVN|hlo",^HLA(200,1,0)="^^1^1^3170627^"  do tail^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"one tail pass drains both the legacy and the HLO store")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772)  do arm^VSLTAP()  set ^HL(772,10,0)="3170627^^^O^^L1^^10^D",^HL(772,10,"IN",1,0)="MSH|x",^HL(772,10,"IN",0)="^^1^1^3170627^"  do tail^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"no consumer -> zero capture, cursor frozen for catch-up on re-arm")
	if '$$enabled^VSLTAP() quit
	do tailLegacy()
	do tailHLO()
	quit
	;
tailLegacy()	; Tail #772 forward from its cursor, teeing each new verbatim message.
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772)  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HL(772,2230625,0)="3170627.01^^^O^^ID1^^2230625^D",^HL(772,2230625,"IN",1,0)="MSH|^~\&|A",^HL(772,2230625,"IN",0)="^^1^1^3170627^"  set ^HL(772,2230648,0)="3170627.01^^^I^^ID2^^2230648^D",^HL(772,2230648,"IN",1,0)="MSH|^~\&|B",^HL(772,2230648,"IN",0)="^^1^1^3170627^"  do tailLegacy^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),2230648,"the #772 cursor advances to the last IEN after tailing both entries")
	do tailStore("772")
	quit
	;
tailHLO()	; Tail #778/#777 forward from its cursor, teeing each new verbatim message.
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP"),^HLB,^HLA  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HLB(7,0)="MID^400^^O^link",^HLB(7,1)="MSH|^~\&|X|",^HLB(7,2)="Y||ADT^A01|MID|P|2.4",^HLA(400,1,1,0)="EVN|A01",^HLA(400,1,0)="^^1^1^3170627^"  do tailHLO^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("778"),7,"the #778 cursor advances after tailing the HLO entry")
	do tailStore("778")
	quit
	;
tailStore(store)	; (private) forward-only $ORDER over numeric IENs of one store.
	; doc: @internal
	; doc: @param store  string  "772" (legacy) | "778" (HLO)
	; doc: A per-entry read fault is fenced (off-window recorded) and the cursor
	; doc: still advances past the poison entry — progress over a poison record, and
	; doc: the gap is explicit, never silent. Non-numeric (cross-ref) subs end it.
	new ien,cur
	set cur=$$cursor(store)
	set ien=cur
	for  do tailOne(store,.ien,.cur) quit:ien=""
	quit
	;
tailOne(store,ien,cur)	; (private) one tail step: advance, read-fenced, tee, persist the cursor.
	; doc: @internal
	; doc: @param ien  numeric  by-ref: advanced to the next IEN ("" ends the loop)
	; doc: @param cur  numeric  by-ref: the persisted high-water cursor
	new msg,ok,sent
	set ien=$$nextIen(store,ien)
	quit:ien=""
	do read1(store,ien,.msg,.ok)
	if 'ok do disable^VSLTAP("hl7read")
	if ok,msg]"" set sent=$$tee^VSLTAP(msg)
	set cur=ien
	do setCursor(store,cur)
	quit
	;
nextIen(store,ien)	; (private) the next numeric IEN after `ien`, or "" at the first cross-ref.
	; doc: @internal
	; doc: numeric subscripts collate before the B/C/AF/AI cross-refs; stop there.
	new n
	if store="772" set n=$order(^HL(772,ien))
	else  set n=$order(^HLB(ien))
	if +n'=n set n=""
	quit n
	;
read1(store,ien,msg,ok)	; (private) fenced reassembly of one entry (DO-framed so the trap QUIT is legal).
	; doc: @internal
	; doc: @param msg  string  by-ref OUT: the verbatim message ("" on fault/purged)
	; doc: @param ok   bool    by-ref OUT: 0 iff a fault was fenced
	; doc: Flag-based $ETRAP (ISO, dual-engine; never zgoto, the M4 resident-harness
	; doc: gotcha) — a malformed store entry self-fences instead of aborting the tail.
	new $etrap
	set ok=1,msg=""
	set $etrap="set ok=0,$ecode="""" quit"
	if store="772" set msg=$$readLegacy(ien)
	else  set msg=$$readHLO(ien)
	quit
	;
	; ---------- verbatim reassembly (grounded on the live probe) ----------
	;
readLegacy(ien)	; Reassemble the verbatim CR-delimited message for #772 entry `ien`.
	; doc: @param ien  numeric  the #772 entry IEN
	; doc: @returns    string   segments ^HL(772,ien,"IN",seq,0) joined by $C(13),
	; doc: in seq order; "" when the body was purged (header-only entry).
	; doc: @example   set ^HL(772,100,"IN",1,0)="MSH|^~\&|ROR SITE",^HL(772,100,"IN",2,0)="PID|1||0",^HL(772,100,"IN",3,0)="CSR|VA HEPC"  do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(100),"MSH|^~\&|ROR SITE"_$char(13)_"PID|1||0"_$char(13)_"CSR|VA HEPC","the three #772 'IN' segments rejoin byte-verbatim, CR-delimited")
	; doc: @example   set ^HL(772,200,0)="3170717.234501^^^^^5002230648"  do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(200),"","a purged #772 entry (header only, no 'IN' body) returns the empty string")
	new msg,seq,first
	set msg="",first=1
	for seq=1:1 quit:'$data(^HL(772,ien,"IN",seq))  do
	. set:'first msg=msg_$char(13)
	. set msg=msg_$get(^HL(772,ien,"IN",seq,0))
	. set first=0
	quit msg
	;
readHLO(ien)	; Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body).
	; doc: @param ien  numeric  the #778 (^HLB) entry IEN
	; doc: @returns    string   the MSH (^HLB(ien,1)_^HLB(ien,2)) then the #777 body
	; doc: segments ^HLA(body,1,seq,0), all CR-delimited, in order.
	; doc: @example   set ^HLB(50,0)="MSGID123^900^^O^link",^HLB(50,1)="MSH|^~\&|APP|FAC|",^HLB(50,2)="DEST|FAC2",^HLA(900,1,1,0)="EVN|A01",^HLA(900,1,2,0)="PID|1||12345"  do eq^STDASSERT(.pass,.fail,$$readHLO^VSLHL7TAP(50),"MSH|^~\&|APP|FAC|DEST|FAC2"_$char(13)_"EVN|A01"_$char(13)_"PID|1||12345","MSH(nodes 1+2) prepended to the #777 body segments, CR-delimited, byte-verbatim")
	new msg,body,seq
	set msg=$get(^HLB(ien,1))_$get(^HLB(ien,2))
	set body=+$piece($get(^HLB(ien,0)),"^",2)
	for seq=1:1 quit:'$data(^HLA(body,1,seq))  set msg=msg_$char(13)_$get(^HLA(body,1,seq,0))
	quit msg
	;
	; ---------- forward-only cursor (per store, persisted in ^VSLTAP) ----------
	;
cursor(store)	; The persisted high-water IEN for a store ("772" | "778"); 0 if unset.
	; doc: @param store  string  the store key
	; doc: @returns      numeric the last IEN tailed
	; doc: @example   kill ^VSLTAP("hl7cur","772")  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),0,"an unset cursor reads as 0")
	; doc: @example   set ^VSLTAP("hl7cur","778")=4242  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("778"),4242,"cursor returns the persisted high-water IEN")  kill ^VSLTAP("hl7cur","778")
	quit +$get(^VSLTAP("hl7cur",store))
	;
setCursor(store,ien)	; Persist the high-water IEN for a store.
	; doc: @param store  string  the store key ("772" | "778")
	; doc: @param ien    numeric the high-water IEN to persist
	; doc: @example   do setCursor^VSLHL7TAP("772",99)  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),99,"setCursor persists the high-water IEN, read back by $$cursor")  kill ^VSLTAP("hl7cur","772")
	set ^VSLTAP("hl7cur",store)=+$get(ien)
	quit
	;
resetCursors()	; Clear both cursors (re-tail from the beginning of each store).
	; doc: @example   set ^VSLTAP("hl7cur","772")=5,^VSLTAP("hl7cur","778")=9  do resetCursors^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772")+$$cursor^VSLHL7TAP("778"),0,"resetCursors clears both cursors back to 0")
	kill ^VSLTAP("hl7cur")
	quit
