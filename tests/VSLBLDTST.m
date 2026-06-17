VSLBLDTST	; v-stdlib — VSLBLD (KIDS base build + env-check) test suite.
	; Exercises VSLBLD against a live VistA's KIDS/Kernel API, over the driver
	; stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLBLDTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLBLDTST.m
	;
	; VSLBLD is the packaging seam: it defines the VSL KIDS base build (all the
	; VSL* routines + the VPNG GREETING #8989.51 PARAMETER DEFINITION + a Required
	; Build on the m-stdlib base MSL*0.1*1 + the VSLENV environment-check routine)
	; and the build-time facts a consumer needs. It binds ONLY the KIDS/Kernel
	; programmer API (ICR #10141 XPDUTL); v-pkg performs the actual install/
	; back-out (no duplication of v-pkg's install mechanics — in-`v` waterline).
	;
	; This suite asserts the STRUCTURAL self-description ($$manifest lists the base
	; routines + the Required Build + the patch identity), the programmatic
	; environment check ($$envCheck returns engine/version/Kernel/TLS facts via the
	; self-contained VSLENV), and the R6 version-skew binding ($$requireBase ->
	; $$PATCH^XPDUTL, with a loud ,U-VSL-BLD-..., on a malformed call). The live
	; install -> verify -> back-out -> verify-clean lifecycle at full scale is
	; driven by v-pkg over the driver (a SHELL-level step, like T1.3), not from M.
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tManifestListsBaseComponents(.pass,.fail)
	do tEnvCheckReturnsFacts(.pass,.fail)
	do tRequireBaseDetectsAbsentBase(.pass,.fail)
	do tRequireBaseRejectsBadArg(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tManifestListsBaseComponents(pass,fail)	;@TEST "$$manifest lists the VSL* base routines, the Required Build (MSL*0.1*1) and the patch identity (VSL*1.0*2)"
	new out,n
	set n=$$manifest^VSLBLD(.out)
	do true^STDASSERT(.pass,.fail,n'<5,"the base ships at least the five M1-M4 VSL* modules (got "_n_" routines)")
	do true^STDASSERT(.pass,.fail,$$has(.out,"VSLCFG"),"manifest includes VSLCFG (the M1 config adapter)")
	do true^STDASSERT(.pass,.fail,$$has(.out,"VSLSEC"),"manifest includes VSLSEC (the M4 security adapter)")
	do true^STDASSERT(.pass,.fail,$$has(.out,"VSLTASK"),"manifest includes VSLTASK (the M5 listener adapter)")
	do true^STDASSERT(.pass,.fail,$$has(.out,"VSLBLD"),"manifest includes VSLBLD (the build definition itself)")
	do true^STDASSERT(.pass,.fail,$get(out("requiredBuild"))="MSL*0.1*1","manifest declares the Required Build on the m-stdlib base")
	do true^STDASSERT(.pass,.fail,$get(out("patch"))="VSL*1.0*2","manifest declares the patch identity VSL*1.0*2")
	quit
	;
tEnvCheckReturnsFacts(pass,fail)	;@TEST "$$envCheck returns engine/version/Kernel/TLS facts via the self-contained VSLENV"
	new facts,ok
	set ok=$$envCheck^VSLBLD(.facts)
	do true^STDASSERT(.pass,.fail,ok=1,"$$envCheck succeeds on a live VistA")
	do true^STDASSERT(.pass,.fail,$get(facts("engine"))'="","env-check reports the engine type ("_$get(facts("engine"))_")")
	do true^STDASSERT(.pass,.fail,$get(facts("version"))'="","env-check reports the engine version")
	do true^STDASSERT(.pass,.fail,$data(facts("kernel")),"env-check reports the Kernel version (presence)")
	do true^STDASSERT(.pass,.fail,$data(facts("tls")),"env-check reports the TLS-config presence fact")
	quit
	;
tRequireBaseDetectsAbsentBase(pass,fail)	;@TEST "$$requireBase returns a normal 0 for a base build that is not installed (NOT an error)"
	new r
	set r=$$requireBase^VSLBLD("ZZNOSUCH*9.9*9")
	do true^STDASSERT(.pass,.fail,r=0,"an absent base build is a normal 0 (a not-installed result, not a loud failure)")
	quit
	;
tRequireBaseRejectsBadArg(pass,fail)	;@TEST "$$requireBase on an empty build name raises a clean ,U-VSL-BLD-..., with detail in $$lastError"
	do raises^STDASSERT(.pass,.fail,"set x=$$requireBase^VSLBLD("""")","U-VSL-BLD","$$requireBase with no build name raises U-VSL-BLD-...")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLBLD()'="","lastError carries the malformed-call detail")
	quit
	;
has(out,name)	; 1 iff routine `name` appears in the manifest's routines() list.
	new i
	set i=""
	for  set i=$order(out("routines",i)) quit:i=""!(out("routines",i)=name)
	quit i'=""
