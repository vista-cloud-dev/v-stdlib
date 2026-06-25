VSLENV	; v-stdlib — the VSL KIDS environment-check routine (the XPDENV hook).
	; doc: @exrun live
	;
	; The single, SELF-CONTAINED environment-check routine named by the VSL KIDS
	; base build (kids/vsl.build.json "envCheck"). KIDS loads ONLY this routine on
	; the target at check time and runs it TWICE — once at Load a Distribution and
	; again at Install (the key variable XPDENV signals the phase) — so it must not
	; call any other VSL*/STD* routine from the build (none are loaded yet); it
	; uses only intrinsics + RESIDENT Kernel APIs (architecture §7.2, KIDS DG).
	;
	; It fails fast on a genuine showstopper (Kernel absent -> XPDQUIT) and reports
	; the engine type/version, Kernel patch level and TLS-config presence — the
	; facts a VWEB-class consumer Requires and extends (engine, TLS, Kernel level,
	; IRIS-for-Health minimum). The programmatic $$check entry returns those facts
	; without touching KIDS state, so a consumer/tests can read them off-install.
	;
	; Public API:
	;   VSLENV            — the KIDS env-check entry (run by KIDS; honors XPDENV/XPDQUIT)
	;   $$check^VSLENV(facts) — fill facts(engine,version,kernel,tls); always returns 1
	;
	new facts,x
	do BMES^XPDUTL("VSL environment check (XPDENV="_$get(XPDENV)_")")
	set x=$$check(.facts)
	do MES^XPDUTL("  engine:  "_facts("engine")_" / "_facts("version"))
	do MES^XPDUTL("  Kernel:  "_$select(facts("kernel")'="":facts("kernel"),1:"NOT FOUND"))
	do MES^XPDUTL("  TLS cfg: "_$select(facts("tls")'="":"present",1:"(none)"))
	if facts("kernel")="" do abort
	quit
	;
abort	; (private) a genuine showstopper — Kernel (XU) is not present; abort the install.
	; doc: @icr 10141 @call MES^XPDUTL @status Supported @custodian XU @source XU/krn_8_0_dg_kids_ug#mesxpdutl-output-a-message
	; doc: @illustrative  only meaningful inside a live KIDS install — MES^XPDUTL needs the KIDS message buffer + it sets the KIDS XPDQUIT install-control flag
	do MES^XPDUTL("  ABORT: Kernel (XU) is not present — the VSL base Requires it")
	set XPDQUIT=2
	quit
	;
	; ---------- the programmatic environment facts (self-contained) ----------
	;
check(facts)	; Fill facts(engine,version,kernel,tls) from intrinsics + resident Kernel; return 1.
	; doc: @param   facts    array    (by ref) receives engine/version/kernel/tls facts
	; doc: @returns          bool     always 1 (faultable reads are isolated + trapped)
	; doc: @example  set x=$$check^VSLENV(.facts) do eq^STDASSERT(.pass,.fail,x,1,"check returns 1")
	; doc: @example  set x=$$check^VSLENV(.facts) do true^STDASSERT(.pass,.fail,facts("engine")'="","check fills a non-empty engine fact")
	; doc: @example  set x=$$check^VSLENV(.facts) do eq^STDASSERT(.pass,.fail,facts("version"),$zversion,"check reports the running engine version")
	set facts("engine")=$select($zversion["IRIS":"IRIS",$zversion["YottaDB":"YottaDB",1:$piece($zversion," ",1))
	set facts("version")=$zversion
	set facts("kernel")=$$kernelVer()
	set facts("tls")=$$tlsConfig()
	quit 1
	;
kernelVer()	; (private) the Kernel (#9.4 XU) current version, "" if unavailable.
	; doc: @icr 10141 @call $$VERSION^XPDUTL @status Supported @custodian XU @source XU/krn_8_0_dg_kids_ug#versionxpdutl-package-file-current-version
	; doc: @example  do true^STDASSERT(.pass,.fail,$$kernelVer^VSLENV()'="","kernelVer is non-empty on a Kernel-equipped VistA")
	new $etrap,v
	set v=""
	set $etrap="set $ecode="""" quit"
	set v=$$VERSION^XPDUTL("XU")
	quit v
	;
tlsConfig()	; (private) the DEFAULT TLS SERVER CONFIG Kernel System Parameter (presence), "" if unset.
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	; doc: @example  do eq^STDASSERT(.pass,.fail,$$tlsConfig^VSLENV(),$$GET^XPAR("SYS","DEFAULT TLS SERVER CONFIG",1),"tlsConfig reads the DEFAULT TLS SERVER CONFIG parameter")
	new $etrap,v
	set v=""
	set $etrap="set $ecode="""" quit"
	set v=$$GET^XPAR("SYS","DEFAULT TLS SERVER CONFIG",1)
	quit v
