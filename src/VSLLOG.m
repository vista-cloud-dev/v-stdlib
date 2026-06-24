VSLLOG	; v-stdlib — VistA FileMan audit-sink adapter (the S3 audit seam).
	;
	; Binds the observability sink to a VistA FileMan audit file. VSLLOG is the
	; first v->v composition: it writes audit records by REUSING VSLFS (the
	; FileMan DBS record writer) rather than re-binding UPDATE^DIE/$$GET1^DIQ
	; itself — the in-`v` analog of the waterline no-duplication rule (a `v` tool
	; consumes a lower `v` capability; only `v->m`/leaked-VistA-symbols are
	; forbidden, never a VSL*->VSL* call). VSLLOG adds ONLY the log-record ->
	; FileMan-field mapping: it composes a timestamped audit line (the timestamp
	; from $$now^STDDATE(), portable, called up — v->m) and files it as the
	; record's .01 via $$set^VSLFS.
	;
	; Public API (the handle is the FileMan IENS VSLFS returns):
	;   $$write^VSLLOG(file,event,detail) — file one audit record -> resolved IENS
	;   $$read^VSLLOG(file,iens)          — read an audit line back, else ""
	;   $$lastError^VSLLOG()              — last error detail, else ""
	;
	; *** ERROR CONTRACT — loud, never a silent lost record ***
	; A FileMan write failure surfaces from VSLFS as ,U-VSL-FS-DIERR,; VSLLOG
	; catches it and re-raises a clean ,U-VSL-LOG-WRITE, $ECODE, carrying the
	; underlying VSLFS detail in ^TMP($job,"vsllog","err") for $$lastError. The
	; "audit log must never silently drop a record" goal (§6.2): a sink failure is
	; loud, not swallowed. Reads of an absent record return "" (as VSLFS reads do).
	;
	; No @icr declarations here: VSLLOG makes NO direct L4 call — every FileMan
	; DBS call is inside VSLFS (declared there), and $$now^STDDATE is an `m`-layer
	; (STD*) call up, not an L4 reference. The v->v + v->m composition is correct
	; by construction and invisible to the ICR/no-direct-global gate.
	;
	quit
	;
	; ---------- the audit sink, bound to FileMan via VSLFS (v->v) ----------
	;
write(file,event,detail)	; File one audit record into `file`; return the resolved IENS, else raise.
	; doc: @param   file     numeric  FileMan audit-file number
	; doc: @param   event    string   short event name (audit category)
	; doc: @param   detail   string   free-text detail for the record
	; doc: @returns          string   the resolved IENS of the new audit record
	; doc: @raises  U-VSL-LOG-WRITE  the FileMan write failed (detail in $$lastError)
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT,ie=$$write^VSLLOG(8989.51,"ZZVSLLOGEX","X") do contains^STDASSERT(.pass,.fail,$$read^VSLLOG(8989.51,ie),"ZZVSLLOGEX","write then read-back contains the event") set zzok=$$kill^VSLFS(8989.51,ie)
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do raises^STDASSERT(.pass,.fail,"set x=$$write^VSLLOG(99999999,""ZZ"",""X"")","U-VSL-LOG-WRITE","writing into a bogus file raises U-VSL-LOG-WRITE")
	new $etrap,iens,line,ok
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	set line=$$now^STDDATE()_" "_event_" "_detail
	set iens=$$set^VSLFS(file,"+1,",".01",line)
	if ok quit iens
	set $etrap="" do raiseWrite quit ""
	;
raiseWrite	; (private) map a downstream VSLFS fault to a loud ,U-VSL-LOG-WRITE,.
	new detail
	set detail=$$lastError^VSLFS()
	set ^TMP($job,"vsllog","err")="write: "_$select(detail'="":detail,1:"FileMan write failed")
	set $ecode=",U-VSL-LOG-WRITE,"
	quit
	;
read(file,iens)	; Read the audit line stored at (file,iens) .01, else "".
	; doc: @param   file     numeric  FileMan audit-file number
	; doc: @param   iens     string   IENS of the audit record
	; doc: @returns          string   the stored audit line, or "" if absent
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$read^VSLLOG(8989.51,"9999999,"),"","read of an absent record returns empty string")
	quit $$get^VSLFS(file,iens,".01","")
	;
lastError()	; The last VSLLOG error message (the composed FileMan detail).
	; doc: @returns          string   ^TMP($job,"vsllog","err"), or "" if none
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do raises^STDASSERT(.pass,.fail,"set x=$$write^VSLLOG(99999999,""ZZ"",""X"")","U-VSL-LOG-WRITE","seed a failure") do true^STDASSERT(.pass,.fail,$$lastError^VSLLOG()'="","lastError carries the FileMan detail after a failed write")
	quit $get(^TMP($job,"vsllog","err"))
