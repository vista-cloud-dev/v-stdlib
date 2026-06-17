VSLFSTST	; v-stdlib — VSLFS (FileMan DBS storage adapter) test suite.
	; Exercises VSLFS against a live VistA's FileMan DBS API, over the driver
	; stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLFSTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLFSTST.m
	;
	; The "test FileMan file" is a DEDICATED throwaway file — #999000 ZZVSLFS —
	; installed from scratch by `v pkg install` (the FileMan FILE-DD enabler) for
	; the duration of this run, then backed out. Its single .01 (NAME) is uppercase
	; free text, 1-30 chars, with NO other required fields, so a ZZ-namespaced
	; record can be created and deleted cleanly through the DBS API. Each test
	; creates a uniquely-named record and removes it; the .01 NAME is uppercase
	; free text, so the round-trip value is transform-invariant (byte-identical
	; set->get over real FileMan). The DD must be RESIDENT before this suite runs.
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tCreateGetRoundtrip(.pass,.fail)
	do tExistsThenKill(.pass,.fail)
	do tDierrIsLoud(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tCreateGetRoundtrip(pass,fail)	;@TEST "$$set creates a record and $$get reads its field back byte-identical"
	new file,name,iens
	do setup(.file)
	set name="ZZVSLFS "_$job_"RT"
	set iens=$$set^VSLFS(file,"+1,",".01",name)
	do true^STDASSERT(.pass,.fail,iens'="","record created (got a resolved IENS)")
	quit:iens=""
	do eq^STDASSERT(.pass,.fail,$$get^VSLFS(file,iens,".01","MISS"),name,"field reads back byte-identical")
	do teardown(file,iens)
	quit
	;
tExistsThenKill(pass,fail)	;@TEST "$$exists is true after create; $$kill removes the record so $$exists is false and $$get returns default"
	new file,name,iens,x
	do setup(.file)
	set name="ZZVSLFS "_$job_"EK"
	set iens=$$set^VSLFS(file,"+1,",".01",name)
	quit:iens=""
	do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(file,iens),1,"record exists after create")
	set x=$$kill^VSLFS(file,iens)
	do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(file,iens),0,"record gone after kill")
	do eq^STDASSERT(.pass,.fail,$$get^VSLFS(file,iens,".01","gone"),"gone","killed field reads as default")
	quit
	;
tDierrIsLoud(pass,fail)	;@TEST "a FileMan DIERR maps to a clean ,U-VSL-FS-..., $ECODE with the detail in $$lastError"
	new file
	do setup(.file)
	do raises^STDASSERT(.pass,.fail,"set x=$$set^VSLFS(99999999,""+1,"","".01"",""ZZ"")","U-VSL-FS","$$set into a bogus file raises U-VSL-FS-...")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLFS()'="","lastError carries the FileMan DIERR detail")
	quit
	;
	; ---------- fixtures ----------
	;
setup(file)	; FileMan programmer context + the dedicated test file (#999000 ZZVSLFS).
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
	set file=999000
	quit
	;
teardown(file,iens)	; Remove the throwaway record if it still exists.
	new x
	quit:'$$exists^VSLFS(file,iens)
	set x=$$kill^VSLFS(file,iens)
	quit
