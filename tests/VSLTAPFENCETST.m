VSLTAPFENCETST	; v-stdlib — FU-4: the $ZREFERENCE (naked-reference) fence property suite.
	; The correctness keystone of the whole tap (spec §6.1.1, R-NAKED). The tap's
	; in-path work is global SETs into ^XTMP — which MUTATE the caller's naked
	; reference ($ZREFERENCE). If the fenced side-call returned with the naked
	; indicator left pointing at ^XTMP, the caller's very next naked reference
	; (`^(sub)`) would silently read/write the WRONG global — a silent,
	; patient-safety-adjacent corruption. The fence must save $ZREFERENCE at the
	; capture boundary and re-establish it on EVERY exit (success, gated, and a
	; swallowed fault) via one benign full reference, so the caller's naked
	; indicator is bit-identical with the tap ON or OFF.
	;
	; Mitigation under test = A (save/restore $ZREFERENCE) in capture^VSLRPCTAP,
	; the boundary the XWB wrap (FU-5) calls. $ZREFERENCE is read-only on YDB+IRIS
	; (plan §12.1.1 AC-3) so the restore is `s zz=$d(@nref)` — a full reference
	; that re-points the indicator without reading the value. Acceptance criteria
	; AC-1..AC-7 (plan §12.1.1).
	;
	; PROBE TECHNIQUE: after the fenced call, do ONE naked reference `s ^(N)=...`
	; and snapshot — into LOCALS, before any STDASSERT call (which may touch
	; globals) — WHERE it landed. If the fence held, `^(N)` resolves under the
	; caller's seed global; if it leaked, it lands in the tap's ^XTMP tree.
	;
	; Bare engine, no VistA, no egress:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPFENCETST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPFENCETST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tNakedRefPreservedOnSuccess(.pass,.fail)
	do tNakedRefRestoredAfterWriteFault(.pass,.fail)
	do tNakedRefRestoredOnPreWriteFault(.pass,.fail)
	do tCallerStateBitIdenticalOnFault(.pass,.fail)
	do tEmptyNakedRefHandled(.pass,.fail)
	do tUnusualSubscriptsRestored(.pass,.fail)
	do tExtendedNamespaceRefIris(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe all tap state + the test's caller-side scratch global
	kill ^VSLTAP,^XTMP("VSLTAP"),^TMP("VSLTFNT",$job)
	quit
	;
isIris()	; (private) 1 on IRIS, 0 on YDB.
	quit $zversion["IRIS"
	;
tNakedRefPreservedOnSuccess(pass,fail)	;@TEST "AC-4: a SUCCESSFUL tee leaves the caller's naked reference under its own global, not ^XTMP"
	new msg,landed,leaked
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set msg="ORWU DT^DUZ=10^NOW"
	; the caller's last full reference BEFORE the side-call (its "^G(1,2,3)")
	set ^TMP("VSLTFNT",$job,1,2,3)="seed"
	do capture^VSLRPCTAP(msg)
	; ONE naked reference — must resolve under ^TMP("VSLTFNT",$J,1,2,*) if the fence held
	set ^(9)="probe"
	set landed=$data(^TMP("VSLTFNT",$job,1,2,9))
	set leaked=$data(^XTMP("VSLTAP","data",9))
	do true^STDASSERT(.pass,.fail,$$size^VSLTAP()=1,"sanity: the tee captured one record")
	do eq^STDASSERT(.pass,.fail,landed,1,"the caller's naked reference still resolves under its own global")
	do eq^STDASSERT(.pass,.fail,leaked,0,"the naked reference did NOT leak into the tap's ^XTMP tree")
	quit
	;
tNakedRefRestoredAfterWriteFault(pass,fail)	;@TEST "AC-1: a fault AFTER the ^XTMP SET still restores the caller's naked reference (the restore is in the finally path)"
	new msg,landed
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	; fire the fault AFTER write1 has SET ^XTMP (so the tap itself dirtied the indicator)
	set ^VSLTAP("cfg","faultinjectpost")=1
	set msg="WILL FAULT POST-WRITE"
	set ^TMP("VSLTFNT",$job,1,2,3)="seed"
	do capture^VSLRPCTAP(msg)
	set ^(9)="probe"
	set landed=$data(^TMP("VSLTFNT",$job,1,2,9))
	do eq^STDASSERT(.pass,.fail,landed,1,"naked reference restored even though the fault fired after the ^XTMP SET")
	do true^STDASSERT(.pass,.fail,$$disabled^VSLTAP()'="","the tap self-disabled on the swallowed fault (fail-safe-OFF)")
	quit
	;
tNakedRefRestoredOnPreWriteFault(pass,fail)	;@TEST "AC-1: a fault BEFORE the ^XTMP SET (indicator dirtied only by the gate reads) still restores"
	new msg,landed
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinject")=1
	set msg="WILL FAULT PRE-WRITE"
	set ^TMP("VSLTFNT",$job,1,2,3)="seed"
	do capture^VSLRPCTAP(msg)
	set ^(9)="probe"
	set landed=$data(^TMP("VSLTFNT",$job,1,2,9))
	do eq^STDASSERT(.pass,.fail,landed,1,"naked reference restored after a pre-write fault")
	quit
	;
tCallerStateBitIdenticalOnFault(pass,fail)	;@TEST "AC-5: $TEST / $ECODE / $ESTACK are bit-identical across a swallowed fault"
	new msg,savedt,savedec,es0,es1
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinjectpost")=1
	set msg="WILL FAULT"
	set $ecode=""
	set es0=$estack
	; establish a known $TEST (=1) immediately before the side-call
	if 1
	do capture^VSLRPCTAP(msg)
	set savedt=$test,savedec=$ecode,es1=$estack
	do eq^STDASSERT(.pass,.fail,savedt,1,"$TEST preserved across the fenced tee")
	do eq^STDASSERT(.pass,.fail,savedec,"","$ECODE clean after the swallowed fault")
	do eq^STDASSERT(.pass,.fail,es1,es0,"$ESTACK bit-identical across the tee")
	quit
	;
tEmptyNakedRefHandled(pass,fail)	;@TEST "AC-2: capture completes cleanly (no error) — the nref='' guard never attempts $d(@'')"
	new msg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set $ecode=""
	set msg="NO PRIOR NAKED REF NEEDED"
	; The guard `i nref'="" s zz=$d(@nref)` makes a job-start empty indicator safe;
	; here we assert the fence path raises nothing regardless of the prior reference.
	do capture^VSLRPCTAP(msg)
	do eq^STDASSERT(.pass,.fail,$ecode,"","the fence restore raised no error (nref guard holds)")
	quit
	;
tUnusualSubscriptsRestored(pass,fail)	;@TEST "AC-7: an indicator on unusual subscripts (special chars, deep, numeric-canonical) is restored bit-exact"
	new msg,landed,sub
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinjectpost")=1
	set msg="UNUSUAL"
	set sub="a,b=c^d"_$char(9)
	; deep + string subscript carrying delimiters/control bytes; canonical-number sibling
	set ^TMP("VSLTFNT",$job,"x",sub,007)="seed"
	do capture^VSLRPCTAP(msg)
	set ^(42)="probe"
	set landed=$data(^TMP("VSLTFNT",$job,"x",sub,42))
	do eq^STDASSERT(.pass,.fail,landed,1,"naked reference on unusual subscripts restored bit-exact")
	quit
	;
tExtendedNamespaceRefIris(pass,fail)	;@TEST "AC-7: an IRIS extended/namespace reference round-trips the fence (YDB: not exercised — documented)"
	new msg,landed,nsp,base
	if '$$isIris() do true^STDASSERT(.pass,.fail,1,"YDB extended-region refs not exercised here (IRIS-primary; documented limitation)") quit
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinjectpost")=1
	set msg="EXTENDED"
	set nsp=$znspace
	; extended reference into the CURRENT namespace (always resolvable on the bare engine)
	set base="^|"""_nsp_"""|TMP(""VSLTFNT"","_$job_",5,6)"
	set @base="seed"
	do capture^VSLRPCTAP(msg)
	set ^(8)="probe"
	set landed=$data(@("^|"""_nsp_"""|TMP(""VSLTFNT"","_$job_",5,8)"))
	do eq^STDASSERT(.pass,.fail,landed,1,"IRIS extended/namespace reference restored across the fence")
	quit
