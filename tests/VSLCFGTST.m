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
	new key,exp
	do setup(.key)
	quit:key=""
	do set^VSLCFG(key,"howdy")
	; getEffective wraps $$GET^XPAR("ALL") (entity-precedence resolution) + the default.
	; When SYS is in this param's precedence (engine/param-dependent — some SYS-settable
	; params, e.g. BPS USRSCR on foia, omit SYS from precedence so ALL returns "") the
	; resolution is "howdy"; otherwise the default. Assert it matches that resolution.
	set exp=$$GET^XPAR("ALL",key,1) set:exp="" exp="MISS"
	do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG(key,"MISS"),exp,"effective read returns the ALL-precedence resolution (default when none)")
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
