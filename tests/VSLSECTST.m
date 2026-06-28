VSLSECTST	; v-stdlib — VSLSEC (VistA identity/authorization adapter) test suite.
	; Exercises VSLSEC against a live VistA's Kernel identity surface, over the
	; driver stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLSECTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLSECTST.m
	;
	; VSLSEC is the VistA *authorization decision* (no portable crypto — that
	; stays in STDCRYPTO; grounded 2026-06-16: no portable Kernel generic-hash
	; entry point exists — SHAHASH^XUSHSH is absent on vehu and classic ^XUSHSH
	; gives constant output on both engines). The seam binds three things:
	;   - $$hasKey: a security-key authorization decision over ^XUSEC (the
	;     documented Supported reference; a DENY is a normal 0, NOT an error);
	;   - $$duz:    the ambient principal (DUZ = the #200 IEN binding);
	;   - $$user:   the principal -> NEW PERSON (#200) NAME, resolved by REUSING
	;     VSLFS (v->v composition; no FileMan DBS re-bind).
	; Fixtures are EXISTING low-risk entries probed read-only (an existing
	; ^XUSEC(key,duz) pair; #200 IEN 1 = the postmaster). No keys are granted or
	; revoked and no users are altered.
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tHasKeyDecision(.pass,.fail)
	do tHasKeyDefaultsDuz(.pass,.fail)
	do tDuzAndUser(.pass,.fail)
	do tUserDefaultsDuz(.pass,.fail)
	do tDuzZeroWhenNoSignon(.pass,.fail)
	do tMalformedIsLoud(.pass,.fail)
	do tParseQry(.pass,.fail)
	do tBySecidEmptyIsLoud(.pass,.fail)
	do tBySecidNoMatch(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
hasXupsqry()	; 1 iff the SecID lookup API (EN1^XUPSQRY) is present (a live VistA).
	quit $text(EN1^XUPSQRY)'=""
	;
hasFileMan()	; 1 iff the FileMan DBS API ($$GET1^DIQ) is present (a live VistA).
	quit $text(GET1^DIQ)'=""
	;
tHasKeyDecision(pass,fail)	;@TEST "$$hasKey is true for a held key (probed read-only) and false for an unheld key (a DENY is a normal 0)"
	new key,duz
	do setup
	do probeHeldKey(.key,.duz)
	if (key'="")&(duz'="") do eq^STDASSERT(.pass,.fail,$$hasKey^VSLSEC(key,duz),1,"hasKey is 1 for a key the user holds")
	do eq^STDASSERT(.pass,.fail,$$hasKey^VSLSEC("ZZ NO SUCH KEY",+$get(duz)),0,"hasKey is 0 (a normal DENY) for an unheld key")
	quit
	;
tHasKeyDefaultsDuz(pass,fail)	;@TEST "single-arg $$hasKey(key) defaults duz to +$GET(DUZ) and returns a clean 0 (no UNDEF)"
	; The documented default-principal contract: omitting duz must fall back to the
	; ambient DUZ, not raise. Regression guard for baseline-audit defect (1). The
	; call is run under $$safeRun so a (pre-fix) UNDEF fails this test cleanly rather
	; than aborting the whole suite to 0/0.
	new raised
	do setup
	kill ^TMP($job,"vslsectst")
	set raised=$$safeRun("set ^TMP($job,""vslsectst"")=$$hasKey^VSLSEC(""ZZ NO SUCH KEY"")")
	do false^STDASSERT(.pass,.fail,raised,"single-arg $$hasKey does not raise (duz defaults to +$GET(DUZ))")
	do:'raised eq^STDASSERT(.pass,.fail,+$get(^TMP($job,"vslsectst")),0,"single-arg $$hasKey returns 0 (DENY) for an unheld key")
	kill ^TMP($job,"vslsectst")
	quit
	;
tUserDefaultsDuz(pass,fail)	;@TEST "single-arg $$user() defaults duz to +$GET(DUZ) and resolves the #200 NAME (live VistA)"
	new raised
	do setup
	if '$$hasFileMan() do true^STDASSERT(.pass,.fail,1,"FileMan absent (bare engine) - single-arg $$user verified on vehu/foia") quit
	kill ^TMP($job,"vslsectst")
	set raised=$$safeRun("set ^TMP($job,""vslsectst"")=$$user^VSLSEC()")
	do false^STDASSERT(.pass,.fail,raised,"single-arg $$user does not raise (duz defaults to the ambient DUZ)")
	do:'raised true^STDASSERT(.pass,.fail,$get(^TMP($job,"vslsectst"))'="","single-arg $$user resolves the #200 NAME for the ambient DUZ (got: "_$get(^TMP($job,"vslsectst"))_")")
	kill ^TMP($job,"vslsectst")
	quit
	;
tDuzZeroWhenNoSignon(pass,fail)	;@TEST "$$duz returns 0 when there is no ambient signon context (DUZ undefined)"
	new DUZ
	do eq^STDASSERT(.pass,.fail,$$duz^VSLSEC(),0,"$$duz is 0 with no ambient DUZ")
	quit
	;
tDuzAndUser(pass,fail)	;@TEST "$$duz returns the ambient principal and $$user resolves its #200 NAME via VSLFS"
	new nm
	do setup
	do eq^STDASSERT(.pass,.fail,$$duz^VSLSEC(),1,"$$duz returns the ambient DUZ")
	if '$$hasFileMan() do true^STDASSERT(.pass,.fail,1,"FileMan ($$GET1^DIQ) absent (bare engine) - $$user #200 read verified on vehu/foia") quit
	set nm=$$user^VSLSEC(1)
	do true^STDASSERT(.pass,.fail,nm'="","$$user resolves the #200 NAME for IEN 1 (got: "_nm_")")
	quit
	;
tMalformedIsLoud(pass,fail)	;@TEST "a malformed call (empty key) maps to a clean ,U-VSL-SEC-..., $ECODE with detail in $$lastError"
	do setup
	do raises^STDASSERT(.pass,.fail,"set x=$$hasKey^VSLSEC("""",1)","U-VSL-SEC","$$hasKey with an empty key raises U-VSL-SEC-...")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLSEC()'="","lastError carries the malformed-call detail")
	quit
	;
tParseQry(pass,fail)	;@TEST "$$parseQry extracts the #200 IEN from an XUPSQRY result array (both engines, no VistA)"
	new R
	; a found record: ^TMP($J,"XUPSQRY",1)=1 (found), (1,0)=VPID^IEN^name~...
	set R(1)=1,R(1,0)="V123^4567^DOE~JOHN~A^000112222^2500101^M^"
	do eq^STDASSERT(.pass,.fail,$$parseQry^VSLSEC(.R),4567,"the #200 IEN is the 2nd ^-piece of the record node")
	; a no-match: flag node is 0
	kill R set R(1)=0
	do eq^STDASSERT(.pass,.fail,$$parseQry^VSLSEC(.R),"","a no-match (flag 0) yields """"")
	; an empty/absent result
	kill R
	do eq^STDASSERT(.pass,.fail,$$parseQry^VSLSEC(.R),"","an empty result yields """"")
	quit
	;
tBySecidEmptyIsLoud(pass,fail)	;@TEST "$$bySecid with an empty SecID is a loud malformed call (U-VSL-SEC-...)"
	do setup
	do raises^STDASSERT(.pass,.fail,"set x=$$bySecid^VSLSEC("""")","U-VSL-SEC","$$bySecid("""") raises U-VSL-SEC-...")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLSEC()'="","lastError carries the malformed-call detail")
	quit
	;
tBySecidNoMatch(pass,fail)	;@TEST "$$bySecid for a non-existent SecID returns """" (callable + no-match) [live VistA only]"
	do setup
	if '$$hasXupsqry() do true^STDASSERT(.pass,.fail,1,"EN1^XUPSQRY absent (bare engine) - SecID lookup verified on vehu/foia") quit
	do eq^STDASSERT(.pass,.fail,$$bySecid^VSLSEC("ZZNO-SUCH-SECID-99999"),"","an unprovisioned SecID resolves to no #200 IEN")
	quit
	;
	; ---------- fixtures ----------
	;
safeRun(code)	; Return 1 iff XECUTEing `code` raised, else 0 — the IRIS-safe raise capture.
	; Mirrors raises^STDASSERT's engine split: IRIS has no ZGOTO/$ZLEVEL unwind (the
	; $ETRAP+arg-less-QUIT path faults NOTEXTRINSIC when a $$ frame is on the stack —
	; the M4 VSLLOG gotcha), so IRIS uses ObjectScript try/catch; YDB uses $ETRAP+ZGOTO
	; to a label (never an arg-less QUIT). Lets a test assert "does NOT raise" without
	; aborting the suite.
	new $etrap,captured,lvl
	set captured="",$ecode=""
	if $zversion["IRIS" do irisSafe(.captured,code) quit captured'=""
	set lvl=$zlevel
	set $etrap="use $principal set captured=$ecode set $ecode="""" zgoto "_lvl_":safeRunDone"
	; m-lint: disable-next-line=M-MOD-036
	xecute code
safeRunDone	; trap-resume target (also reached on clean fall-through)
	set $ecode=""
	; m-lint: disable-next-line=M-MOD-024
	quit captured'=""
	;
irisSafe(captured,code)	; IRIS: capture a raise from `code` via ObjectScript try/catch.
	set captured=""
	; m-lint: disable-next-line=M-MOD-036
	xecute "try { xecute code } catch ex { set captured=$ecode }"
	use $principal
	set $ecode=""
	quit
	;
setup	; FileMan programmer context (needed for the #200 NAME read via VSLFS).
	; $$DT^XLFDT is Kernel — absent on a bare engine; fall back so the pure-logic
	; tests still run dual-engine (DT only matters for the live FileMan reads).
	set DUZ=1,DUZ(0)="@",U="^"
	set DT=$select($text(DT^XLFDT)'="":$$DT^XLFDT,1:3000101)
	quit
	;
probeHeldKey(key,duz)	; Find an existing ^XUSEC(key,duz) pair, read-only (test ground truth).
	new $etrap
	set key="",duz=""
	set $etrap="set $ecode="""" quit"
	set key=$order(^XUSEC(""))
	if key'="" set duz=$order(^XUSEC(key,0))
	quit
