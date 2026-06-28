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
	do tFindByName(.pass,.fail)
	do tListAllRecords(.pass,.fail)
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
tFindByName(pass,fail)	;@TEST "$$find returns the IENS of a uniquely-named record by the B index, and "" when absent"
	new file,name,iens,found
	do setup(.file)
	set name="ZZVSLFS "_$job_"FIND"
	set iens=$$set^VSLFS(file,"+1,",".01",name)
	quit:iens=""
	set found=$$find^VSLFS(file,name,"B")
	do eq^STDASSERT(.pass,.fail,found,iens,"$$find resolves the record's IENS by exact .01")
	do eq^STDASSERT(.pass,.fail,$$find^VSLFS(file,"ZZVSLFS NOSUCH "_$job,"B"),"","$$find returns empty for an absent value")
	do teardown(file,iens)
	quit
	;
tListAllRecords(pass,fail)	;@TEST "$$list returns the IENS of every record (the two just created are present)"
	new file,n1,n2,i1,i2,out,cnt
	do setup(.file)
	set n1="ZZVSLFS "_$job_"L1",n2="ZZVSLFS "_$job_"L2"
	set i1=$$set^VSLFS(file,"+1,",".01",n1)
	set i2=$$set^VSLFS(file,"+1,",".01",n2)
	quit:(i1="")!(i2="")
	set cnt=$$list^VSLFS(file,.out,"B")
	do true^STDASSERT(.pass,.fail,cnt>=2,"$$list counts at least the two new records")
	do true^STDASSERT(.pass,.fail,$data(out(i1)),"$$list includes the first record's IENS")
	do true^STDASSERT(.pass,.fail,$data(out(i2)),"$$list includes the second record's IENS")
	do teardown(file,i1)
	do teardown(file,i2)
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
