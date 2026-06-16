VSLCFGTST	; v-stdlib — VSLCFG (XPAR config adapter) test suite.
	; Exercises VSLCFG against a live VistA's XPAR (Parameter Tools).
	;
	; BLOCKED on a toolchain gap (see docs/plans/t1.2-vslcfg-design.md): the
	; `m test --docker vehu` staging path honors M_YDB_GBLDIR (globals visible)
	; but NOT M_YDB_ROUTINES, so vehu's VistA routines (^XPAR, ^XLFDT) are absent
	; from $ZROUTINES and $$GET^XPAR/EN^XPAR do not resolve — the suite aborts
	; 0/0. The harness must layer the engine's resident routine base under the
	; staged routines (mirroring the m-ydb $ZGBLDIR fix), or this runs test-in-
	; place via `m test --resident` against installed routines. The fixture and
	; assertions below are correct and ready once a real engine resolves XPAR.
	;
	; Driver-stack invocation (the ONLY path; m/v waterline):
	;   M_YDB_GBLDIR=/home/vehu/g/vehu.gld M_YDB_ROUTINES='<vehu gtmroutines>' \
	;     m test --engine ydb --docker vehu --chset m \
	;       --routines src --routines <m-stdlib>/src tests/VSLCFGTST.m
	;   (IRIS: --engine iris --docker foia-t12 --namespace VISTA)
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tSetGetSysPrecedence(.pass,.fail)
	do tGetDefaultWhenUnset(.pass,.fail)
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
