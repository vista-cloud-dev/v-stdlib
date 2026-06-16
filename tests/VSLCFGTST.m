VSLCFGTST	; v-stdlib — VSLCFG (XPAR config adapter) test suite.
	; Exercises VSLCFG against a live VistA's XPAR (Parameter Tools). Run through
	; the driver stack ONLY (m/v waterline):
	;   M_YDB_GBLDIR=/home/vehu/g/vehu.gld M_YDB_ROUTINES='<vehu gtmroutines>' \
	;     m test --engine ydb --docker vehu --chset m \
	;       --routines src --routines <m-stdlib>/src tests/VSLCFGTST.m
	;   (IRIS: --engine iris --docker foia-t12 --namespace VISTA)
	;
	; STATUS: fixture WIP. The harness + adapter staging are proven (a minimal
	; probe goes 2/2 green via the driver on vehu). The setup/teardown below build
	; a throwaway PARAMETER DEFINITION via direct globals, but EN^XPAR will not
	; FILE a value against such a hand-built def (no error, value not stored), so
	; the suite currently aborts 0/0. NEXT: create the #8989.51 def via FileMan
	; (FILE^DIE with the value-type subfield), or seed an existing free-text
	; SYS-settable param with save/restore. See docs/plans/t1.2-vslcfg-design.md.
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
	new key,ien
	set key="ZZVSLCFG TEST"
	do setup(key,.ien)
	do set^VSLCFG(key,"hello")
	do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(key,"MISS"),"hello","SYS precedence read")
	do teardown(key,ien)
	quit
	;
tGetDefaultWhenUnset(pass,fail)	;@TEST "$$get returns the default for a parameter with no value"
	new key,ien
	set key="ZZVSLCFG TEST"
	do setup(key,.ien)
	do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(key,"fallback"),"fallback","unset returns default")
	do teardown(key,ien)
	quit
	;
	; ---------- fixtures (WIP — see header) ----------
	;
setup(key,ien)	; Create a throwaway free-text PARAMETER DEFINITION (#8989.51).
	new hdr
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
	set hdr=$get(^XTV(8989.51,0))
	set ien=$piece(hdr,U,3)+1
	set ^XTV(8989.51,ien,0)=key_U_"VSLCFG test param"_U_U_U_U
	set ^XTV(8989.51,ien,6)="F^1:245"
	set ^XTV(8989.51,"B",key,ien)=""
	set $piece(^XTV(8989.51,0),U,3)=ien
	set $piece(^XTV(8989.51,0),U,4)=$piece(hdr,U,4)+1
	quit
	;
teardown(key,ien)	; Remove the SYS value and the throwaway definition.
	new err
	set DUZ=1,DUZ(0)="@",U="^"
	do EN^XPAR("SYS",key,1,"@",.err)
	kill ^XTV(8989.51,ien,0),^XTV(8989.51,ien,6),^XTV(8989.51,"B",key,ien)
	set:ien $piece(^XTV(8989.51,0),U,3)=ien-1
	quit
