VSLCFGTST	; v-stdlib — VSLCFG (XPAR config adapter) test suite.
	; Exercises VSLCFG against a live VistA's XPAR (Parameter Tools). GREEN 7/7 on
	; BOTH engines via the driver stack (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLCFGTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLCFGTST.m
	; (No M_YDB_* host vars needed — the container's `bash -l` env supplies
	; gtmgbldir + gtmroutines once m-cli's DockerEngine layers the resident routine
	; base; see m-cli memory `docker-routines-gtmroutines-fallback`.)
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tSetGetSysPrecedence(.pass,.fail)
	do tGetDefaultWhenUnset(.pass,.fail)
	do tGetOmittedDefaultIsEmpty(.pass,.fail)
	do tGetEffectiveResolvesSys(.pass,.fail)
	do tSetFailureIsLoud(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tSetGetSysPrecedence(pass,fail)	;@TEST "$$set then $$get round-trips a SYS-level value through XPAR precedence"
	new key
	do setup(.key)
	do true^STDASSERT(.pass,.fail,key'="","a usable XPAR parameter was found")
	quit:key=""
	do set^VSLCFG(key,"hello")
	do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(key,"MISS"),"hello","SYS precedence read")
	do teardown(key)
	quit
	;
tGetDefaultWhenUnset(pass,fail)	;@TEST "$$get returns the default for a parameter with no value"
	new key
	do setup(.key)
	quit:key=""
	do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(key,"fallback"),"fallback","unset returns default")
	do teardown(key)
	quit
	;
tGetOmittedDefaultIsEmpty(pass,fail)	;@TEST "$$get/$$getEffective with the default arg omitted return empty for an unset parameter (no UNDEF)"
	; Contract-shape (the VSLSEC-class bug): an omitted optional `default` must not be
	; evaluated raw. $$get of an unset parameter with no default must yield "" (empty),
	; never UNDEF on the undefined formal.
	set DUZ=1,DUZ(0)="@",U="^"
	do eq^STDASSERT(.pass,.fail,$$get^VSLCFG("ZZVSLCFGNOSUCH"),"","$$get of an unset param with default omitted returns empty (not UNDEF)")
	do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG("ZZVSLCFGNOSUCH"),"","$$getEffective of an unset param with default omitted returns empty (not UNDEF)")
	quit
	;
tGetEffectiveResolvesSys(pass,fail)	;@TEST "$$getEffective returns the ALL-precedence resolution (+ default), distinct from $$get's SYS-only read"
	new key,seen
	do setup(.key)
	quit:key=""
	do set^VSLCFG(key,"howdy")
	; De-circularized: read what ALL resolves to ONCE, then assert getEffective against a
	; KNOWN value (not a second $$GET^XPAR("ALL") call — that was a tautology since
	; getEffective literally wraps it). SYS may or may not be in this param's precedence
	; (engine/param-dependent — e.g. BPS USRSCR on foia omits SYS, so ALL returns "").
	; The seen="" branch is the regression catcher: if getEffective ever read "SYS"
	; instead of "ALL", a SYS-omitting param would wrongly return "howdy" here.
	set seen=$$GET^XPAR("ALL",key,1)
	if seen="howdy" do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG(key,"MISS"),"howdy","SYS participates in precedence: getEffective returns the SYS value we set")
	if seen="" do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG(key,"MISS"),"MISS","SYS omitted from precedence: getEffective is the default, NOT the SYS value (guards an ALL->SYS read)")
	if seen'="howdy",seen'="" do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG(key,"MISS"),seen,"a higher-precedence level dominates: getEffective returns that level's value")
	do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG("ZZVSLCFGNOSUCH","fb"),"fb","effective read of an unset parameter returns the default")
	do teardown(key)
	quit
	;
tSetFailureIsLoud(pass,fail)	;@TEST "a failed $$set maps to a clean ,U-VSL-CFG-..., $ECODE with the detail in $$lastError"
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
	do raises^STDASSERT(.pass,.fail,"do set^VSLCFG(""ZZNOSUCHVSLCFGPARAM"",""x"")",",U-VSL-CFG-SET,","$$set into an undefined parameter raises exactly ,U-VSL-CFG-SET,")
	do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped set raise (clean unwind)")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLCFG()'="","lastError carries the XPAR failure detail")
	quit
	;
	; ---------- fixtures ----------
	;
setup(key)	; Find a free-text, SYS-settable XPAR parameter currently unset at SYS.
	; Probes empty free-text params (set a sentinel, read it back, restore) and
	; returns the first whose SYS set round-trips. Touches only already-empty
	; params and restores each immediately, so no real config is changed.
	new n,i
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT,key=""
	set n=$order(^XTV(8989.51,"B",""))
	for  quit:n=""!(key'="")  do
	. set i=+$order(^XTV(8989.51,"B",n,0))
	. if i,$extract($get(^XTV(8989.51,i,6)))="F",$$GET^XPAR("SYS",n,1)="" do try(n,.key)
	. set n=$order(^XTV(8989.51,"B",n))
	quit
	;
try(n,key)	; Sentinel set/read/restore on one candidate; set key on round-trip.
	new r
	do EN^XPAR("SYS",n,1,"ZZVSLCFGPROBE",.r)
	set r=$$GET^XPAR("SYS",n,1)
	do EN^XPAR("SYS",n,1,"@")
	set:r="ZZVSLCFGPROBE" key=n
	quit
	;
teardown(key)	; Restore the chosen parameter's SYS value to unset.
	new err
	quit:key=""
	set DUZ=1,DUZ(0)="@",U="^"
	do EN^XPAR("SYS",key,1,"@",.err)
	quit
