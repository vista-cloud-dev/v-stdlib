VSLFSTST	; v-stdlib — VSLFS (FileMan DBS storage adapter) test suite.
	; Exercises VSLFS against a live VistA's FileMan DBS API, over the driver
	; stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLFSTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLFSTST.m
	;
	; The "test FileMan file" is an EXISTING low-risk file — #8989.51 PARAMETER
	; DEFINITION — whose .01 (NAME) is free-text with NO other required fields, so
	; a throwaway, ZZ-namespaced record can be created and deleted cleanly through
	; the DBS API (no DD install needed; the DD-install enabler is a deferred
	; v-pkg track). Each test creates a uniquely-named record and removes it; the
	; .01 NAME is uppercase free text, so the round-trip value is chosen
	; transform-invariant (byte-identical set->get over real FileMan).
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
setup(file)	; FileMan programmer context + the safe test file (#8989.51).
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
	set file=8989.51
	quit
	;
teardown(file,iens)	; Remove the throwaway record if it still exists.
	new x
	quit:'$$exists^VSLFS(file,iens)
	set x=$$kill^VSLFS(file,iens)
	quit
