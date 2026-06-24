VSLBLD	; v-stdlib — the VSL KIDS base build definition + env-check binding (packaging seam).
	;
	; Defines the VSL layer's KIDS base build and the build-time facts a consumer
	; needs. The build itself is the drift-gated artifact kids/vsl.build.json ->
	; dist/kids/VSL.kids (gated by `make check-kids`): all the VSL* routines + the
	; VPNG GREETING #8989.51 PARAMETER DEFINITION + a Required Build on the m-stdlib
	; base (MSL*0.1*1, so STD* is reused from one shared install, never copied in)
	; + the VSLENV environment-check routine. VSLBLD binds ONLY the KIDS/Kernel
	; programmer API (ICR #10141, XPDUTL); the actual install / verify / back-out
	; is performed by v-pkg over the driver — VSLBLD does NOT duplicate v-pkg's
	; install mechanics (the in-`v` no-duplication rule; architecture §7.2).
	;
	; Public API:
	;   $$manifest^VSLBLD(out)     — fill out() with the base routines + Required Build + patch identity
	;   $$envCheck^VSLBLD(facts)   — the environment facts (engine/version/Kernel/TLS) via VSLENV (v->v)
	;   $$requireBase^VSLBLD(build) — 1 iff KIDS build `build` is installed (the R6 version-skew check)
	;   $$lastError^VSLBLD()       — last error detail, else ""
	;
	; *** ERROR CONTRACT — loud on a malformed call, never on a normal negative ***
	; A malformed call (an empty build name) maps to a clean ,U-VSL-BLD-ARG, $ECODE
	; with the detail in ^TMP($job,"vslbld","err") for $$lastError. A base that is
	; simply NOT installed is a normal 0 from $$requireBase — NOT an error (kickoff
	; decision 4, the VSLSEC DENY-is-not-an-error posture).
	;
	quit
	;
	; ---------- the build self-description (structural) ----------
	;
manifest(out)	; Fill out() with the VSL base's routines, its Required Build and patch identity; return the routine count.
	; doc: @param   out      array    (by ref) out("routines",n)=routine; out("requiredBuild"); out("patch")
	; doc: @returns          numeric  the number of routines the VSL base ships
	; doc: @example   do true^STDASSERT(.pass,.fail,$$manifest^VSLBLD(.out)'<5,"the base ships at least the five M1-M4 VSL* modules")
	; doc: @example   set n=$$manifest^VSLBLD(.out) do true^STDASSERT(.pass,.fail,$get(out("requiredBuild"))="MSL*0.1*1","manifest declares the Required Build on the m-stdlib base")
	; doc: @example   set n=$$manifest^VSLBLD(.out) do true^STDASSERT(.pass,.fail,$get(out("patch"))="VSL*1.0*3","manifest declares the patch identity VSL*1.0*3")
	new n
	kill out
	set n=0
	do add(.out,.n,"VSLBLD")
	do add(.out,.n,"VSLCFG")
	do add(.out,.n,"VSLENV")
	do add(.out,.n,"VSLFS")
	do add(.out,.n,"VSLIO")
	do add(.out,.n,"VSLLOG")
	do add(.out,.n,"VSLSEC")
	do add(.out,.n,"VSLTASK")
	set out("requiredBuild")="MSL*0.1*1"
	set out("patch")="VSL*1.0*3"
	quit n
	;
add(out,n,rtn)	; (private) append routine `rtn` to the manifest list.
	set n=n+1
	set out("routines",n)=rtn
	quit
	;
	; ---------- the environment-check + version-skew bindings ----------
	;
envCheck(facts)	; The environment facts (engine/version/Kernel/TLS) via the self-contained VSLENV (v->v).
	; doc: @param   facts    array    (by ref) receives engine/version/kernel/tls facts
	; doc: @returns          bool     1 on success
	; doc: @example   do true^STDASSERT(.pass,.fail,$$envCheck^VSLBLD(.facts)=1,"$$envCheck succeeds on a live VistA")
	; doc: @example   set ok=$$envCheck^VSLBLD(.facts) do true^STDASSERT(.pass,.fail,$get(facts("engine"))'="","env-check reports the engine type")
	quit $$check^VSLENV(.facts)
	;
requireBase(build)	; 1 iff KIDS build `build` is installed on this system (the R6 version-skew check).
	; doc: @param   build    string   a KIDS build/patch identity (e.g. "MSL*0.1*1")
	; doc: @returns          bool     1 iff installed; 0 (a normal not-installed result) otherwise
	; doc: @raises  U-VSL-BLD-ARG    the call is malformed (an empty build name)
	; doc: @icr 10141 @call $$PATCH^XPDUTL @status Supported @custodian XU @source XU/krn_8_0_dg_kids_ug#verifying-patch-installation
	; doc: @example   do true^STDASSERT(.pass,.fail,$$requireBase^VSLBLD("ZZNOSUCH*9.9*9")=0,"an absent base build is a normal 0 (a not-installed result, not a loud failure)")
	; doc: @example   do raises^STDASSERT(.pass,.fail,"set x=$$requireBase^VSLBLD("""")","U-VSL-BLD-ARG","$$requireBase with no build name raises U-VSL-BLD-...")
	if $get(build)="" do raise("U-VSL-BLD-ARG","requireBase: a build name is required") quit ""
	quit ''$$PATCH^XPDUTL(build)
	;
lastError()	; The last VSLBLD error message (the composed malformed-call detail).
	; doc: @returns          string   ^TMP($job,"vslbld","err"), or "" if none
	; doc: @example   do raises^STDASSERT(.pass,.fail,"set x=$$requireBase^VSLBLD("""")","U-VSL-BLD-ARG","arming the error state") do true^STDASSERT(.pass,.fail,$$lastError^VSLBLD()'="","lastError carries the malformed-call detail after a rejected call")
	quit $get(^TMP($job,"vslbld","err"))
	;
	; ---------- internals ----------
	;
raise(code,msg)	; (private) stash the detail, then raise the clean ,<code>, $ECODE.
	set ^TMP($job,"vslbld","err")=msg
	set $ecode=","_code_","
	quit
