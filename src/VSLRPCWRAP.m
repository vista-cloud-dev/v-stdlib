VSLRPCWRAP	; v-stdlib — the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK).
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positive: the broker's process-scope vars (XWB/XWBP/XWBSEC/
	; XWBPTYPE/DUZ/XWBTIP/XWBTSKT) are defined by the CALLER (CALLP^XWBBRK), not by
	; this routine; the analyser cannot see that cross-frame definition and reads them
	; as "read before defined". Scalars are $GET-guarded; XWB is walked by $ORDER.
	;
	; Phase 6 / FU-5. The two fenced side-calls that the active broker `CALLP^XWBBRK`
	; invokes around its RPC dispatch (the splice is pinned on live foia+vehu source —
	; byte-identical, RPC BROKER; see docs/discoveries/fu-5b-callp-splice.md):
	;
	;   CALLP^XWBBRK:153  S:$L($G(XWBSEC)) ERR="-1^"_XWBSEC
	;        :153a  D req^VSLRPCWRAP            ; <- NEW (unconditional): one dir=req per RPC
	;        :155   IF '+ERR,(+S=0)!(+S>0) D
	;        :158   . D CAPI^XWBBRK2(.XWBP,XWB(2,"RTAG"),XWB(2,"RNAM"),S)
	;        :158a  . D resp^VSLRPCWRAP        ; <- NEW (success path only): dir=resp
	;
	; *** The splice lines are UNCONDITIONAL (`D req^…`, not `D:$G(^global) req^…`): a
	; global-flag guard in the broker line would itself move the caller's naked indicator
	; BEFORE the FU-4 fence runs, corrupting the broker's next naked reference. A plain
	; `DO routine` does not touch the naked indicator, so the wrap entry owns the fence and
	; gates on `$$captureOn^VSLTAP` from INSIDE it. When the tap is OFF the cost per RPC is
	; one fence save/restore + the gate read — bounded, measured by the 5B non-interference
	; proof.
	;
	; Layer: v (VistA-specific: reads XWB* broker vars). It reads ONLY the broker's
	; process-scope locals (it NEWs nothing the broker owns) and is invisible to the RPC
	; flow: the FU-4 caller-state fence (naked indicator + $TEST) wraps each entry, and the
	; ring write is the self-disabling `$$teeRec^VSLTAP`. It never writes a var the broker
	; depends on — the rec it builds is its own local; the only process vars it sets are the
	; $J-scoped correlation locals VSLWCC/VSLWCID (deliberately VSL-namespaced so a future
	; XWB patch cannot collide). FU-21 re-validates the splice + the var reads per XWB patch.
	;
	; Reads at the wrap depth (all confirmed in process scope on live source):
	;   XWB(2,"CAPI")   the RPC name              XWB(3,"P",*)   the decoded input params
	;   XWBSEC          set iff CHKPRMIT denied   XWBP           the result slot (post-dispatch)
	;   XWBPTYPE        #8994 return type 1..4     DUZ / $J       user / job
	;   XWBTIP:XWBTSKT  client IP:port (EN^XWBTCPC formal params, ancestor frame)
	;
	; Public API (called only from the CALLP^XWBBRK splice):
	;   do req^VSLRPCWRAP()    fenced request side-call  (dir=req, denied flag)
	;   do resp^VSLRPCWRAP()   fenced result side-call   (dir=resp, result by XWBPTYPE)
	;
	quit
	;
req()	; Request side-call: emit a dir=req record for EVERY RPC (incl. denied/errored).
	; doc: @returns void  fire-and-forget; the broker's result/$ECODE/$T/naked-ref are untouched.
	; doc: The FU-4 fence (same pattern as capture^VSLRPCTAP): snapshot $TEST + the naked
	; doc: indicator BEFORE any global reference, re-establish both on EVERY exit. Owning the
	; doc: fence HERE lets reqWork read the gate + config (globals) safely (see the file note).
	new t,nref,zz
	; m-lint: disable-next-line=M-MOD-017
	set t=$test
	set nref=$$nakedRef^VSLRPCTAP()
	do reqWork()
	if nref'="" set zz=$data(@nref)
	if t
	quit
	;
resp()	; Result side-call: emit a dir=resp record on the dispatch-success path.
	; doc: @returns void  fenced exactly like req(); correlated to its request by call_id.
	new t,nref,zz
	; m-lint: disable-next-line=M-MOD-017
	set t=$test
	set nref=$$nakedRef^VSLRPCTAP()
	do respWork()
	if nref'="" set zz=$data(@nref)
	if t
	quit
	;
reqWork()	; (private) DO-framed: gate, build the dir=req rec from broker vars, tee it.
	; doc: MUST stay DO-invoked (never `$$`): the trap's arg-less QUIT raises M17
	; doc: NOTEXTRINSIC in an extrinsic frame (the append/write1 gotcha).
	new rec,x,$etrap
	set $etrap="set $ecode="""" quit"
	if '$$captureOn^VSLTAP() quit
	; bump the $J-scoped correlation counter ONCE per RPC (a LOCAL — naked-ref-free) and
	; build the shared call_id; resp reuses VSLWCID without bumping (same RPC, same id).
	set VSLWCC=$get(VSLWCC)+1
	set VSLWCID=$$callId^VSLRPCTAP($$cfg^VSLTAP("s3station",""),VSLWCC)
	set rec("dir")="req"
	set rec("call_id")=VSLWCID
	set rec("rpc")=$get(XWB(2,"CAPI"))
	set rec("payload")=$$params()
	; denied iff CHKPRMIT set XWBSEC at CALLP:152 (the only point that sees a denial).
	set rec("denied")=$select($length($get(XWBSEC)):1,1:0)
	do ctx(.rec)
	set x=$$teeRec^VSLTAP(.rec)
	quit
	;
respWork()	; (private) DO-framed: build the dir=resp rec (result by XWBPTYPE), tee it.
	new rec,x,$etrap
	set $etrap="set $ecode="""" quit"
	if '$$captureOn^VSLTAP() quit
	set rec("dir")="resp"
	set rec("call_id")=$get(VSLWCID)
	set rec("rpc")=$get(XWB(2,"CAPI"))
	do result(.rec)
	do ctx(.rec)
	set x=$$teeRec^VSLTAP(.rec)
	quit
	;
params()	; (private) join the broker's decoded input params XWB(3,"P",*) verbatim (no typing — §9).
	; doc: @returns byte-string  the params $C(1)-joined in subscript order (FU-16(c): inputs
	; doc: land in XWB(3,"P",*); there is no single param array to grab). A LOCAL $ORDER —
	; doc: it does not touch the naked indicator.
	new i,out
	set out="",i=""
	for  do pStep(.i,.out) quit:i=""
	quit out
	;
pStep(i,out)	; (private) advance to the next XWB(3,"P",*) input node; $C(1)-append it ("" i stops).
	set i=$order(XWB(3,"P",i))
	if i="" quit
	set out=out_$select(out="":"",1:$char(1))_$get(XWB(3,"P",i))
	quit
	;
result(rec)	; (private) classify the result by XWBPTYPE (FU-16(c)) — scalar payload or a snapshot ref.
	; doc: @param rec  array  by-ref: sets result_kind + (payload | gref)
	; doc: XWBPTYPE 1=single -> scalar (XWBP IS the value); 4=global array -> XWBP is a
	; doc: closed-root global ref string (gref=its value); 2=table/3=WP -> XWBP is a LOCAL
	; doc: array tree (gref="XWBP" — write1rec MERGEs @gref). The MERGE is FU-17's one in-path op.
	new ty
	set ty=+$get(XWBPTYPE)
	if ty=4 set rec("result_kind")="global",rec("gref")=$get(XWBP) quit
	if (ty=2)!(ty=3) set rec("result_kind")="array",rec("gref")="XWBP" quit
	set rec("result_kind")="scalar",rec("payload")=$get(XWBP)
	quit
	;
ctx(rec)	; (private) FU-18 context read at the wrap depth (process scope; ancestor EN^XWBTCPC).
	; doc: @param rec  array  by-ref: sets duz/job/client/station
	; doc: DUZ/$J + the client IP:port (XWBTIP:XWBTSKT, EN^XWBTCPC formal params — OPEN-2,
	; doc: read the vars directly, not the truncated procname). All LOCAL reads (no global).
	set rec("duz")=$get(DUZ)
	set rec("job")=$job
	set rec("client")=$get(XWBTIP)_":"_$get(XWBTSKT)
	set rec("station")=$$cfg^VSLTAP("s3station","")
	quit
