VSLLOGTST	; v-stdlib — VSLLOG (FileMan audit-sink adapter) test suite.
	; Exercises VSLLOG against a live VistA's FileMan DBS API, over the driver
	; stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLLOGTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLLOGTST.m
	;
	; VSLLOG is the audit sink: it writes a log record to a FileMan audit file by
	; REUSING VSLFS (v->v composition; it does NOT re-bind the FileMan DBS) and
	; maps a write failure to a clean ,U-VSL-LOG-WRITE, $ECODE. The "audit file"
	; is the same EXISTING low-risk file VSLFS uses — #8989.51 PARAMETER
	; DEFINITION — whose .01 is free-text (uppercased) with no other required
	; fields, so a throwaway ZZ-namespaced audit record is created and removed
	; cleanly (no DD install; the dedicated-audit-file DD is a deferred v-pkg
	; track). The audit line carries a $$now^STDDATE() timestamp (portable, v->m)
	; + the event + detail; the round-trip asserts the read-back CONTAINS the
	; event and detail (the timestamp is generated, so not byte-predictable; the
	; #8989.51 .01 uppercases, so the test content is uppercase).
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tWriteReadRoundtrip(.pass,.fail)
	do tWriteFailureIsLoud(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tWriteReadRoundtrip(pass,fail)	;@TEST "$$write files an audit record via VSLFS and $$read returns a line carrying the event and detail"
	new file,event,detail,iens,line
	do setup(.file)
	set event="ZZVSLLOG-LOGIN"
	set detail="USER=1 JOB="_$job
	set iens=$$write^VSLLOG(file,event,detail)
	do true^STDASSERT(.pass,.fail,iens'="","audit record written (got a resolved IENS)")
	quit:iens=""
	set line=$$read^VSLLOG(file,iens)
	do true^STDASSERT(.pass,.fail,line[event,"read-back audit line contains the event")
	do true^STDASSERT(.pass,.fail,line[detail,"read-back audit line contains the detail")
	do teardown(file,iens)
	quit
	;
tWriteFailureIsLoud(pass,fail)	;@TEST "a FileMan write failure maps to a clean ,U-VSL-LOG-..., $ECODE with detail in $$lastError"
	new file
	do setup(.file)
	do raises^STDASSERT(.pass,.fail,"set x=$$write^VSLLOG(99999999,""ZZ"",""X"")","U-VSL-LOG","$$write into a bogus file raises U-VSL-LOG-...")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLLOG()'="","lastError carries the underlying FileMan detail")
	quit
	;
	; ---------- fixtures ----------
	;
setup(file)	; FileMan programmer context + the safe audit file (#8989.51).
	set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
	set file=8989.51
	quit
	;
teardown(file,iens)	; Remove the throwaway audit record if it still exists (via VSLFS).
	new x
	quit:'$$exists^VSLFS(file,iens)
	set x=$$kill^VSLFS(file,iens)
	quit
