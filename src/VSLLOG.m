VSLLOG	; v-stdlib — VistA FileMan audit sink (the dedicated VSL AUDIT file).
	; doc: @exrun live
	; doc: @exsafe transactional
	;
	; Owns a dedicated VistA FileMan audit file — VSL AUDIT (#999001, data global
	; ^DIZ(999001,) — and writes a STRUCTURED audit record by REUSING VSLFS (the
	; FileMan DBS record writer) rather than re-binding UPDATE^DIE/$$GET1^DIQ itself
	; — the in-`v` analog of the waterline no-duplication rule (a `v` tool consumes
	; a lower `v` capability; only `v->m`/leaked-VistA-symbols are forbidden, never a
	; VSL*->VSL* call). VSLLOG adds ONLY the audit-record -> FileMan-field mapping:
	; .01 EVENT (free text), TIMESTAMP (filed "NOW" — the FileMan date/time input
	; transform, portable), USER NUMBER (the acting DUZ; a plain numeric, NOT a #200
	; pointer, so a system-context record (DUZ 0) files with no NEW PERSON
	; dependency), HOST (the originating $IO), and free-text DETAIL.
	;
	; Public API (the handle is the FileMan IENS VSLFS returns):
	;   $$write^VSLLOG(event,detail,duz,host) — file one audit record -> resolved IENS
	;   $$read^VSLLOG(iens,.rec)              — read a record's typed fields into rec(),
	;                                            return the EVENT (.01), else ""
	;   $$query^VSLLOG(.out,event,fromDt,toDt)— filter records by event + FileMan date
	;                                            range into out("ien,")=event; return count
	;   $$auditFile^VSLLOG()                  — the dedicated VSL AUDIT file number
	;   $$lastError^VSLLOG()                  — last error detail, else ""
	;
	; The file number is a VA-reserved local/test number (#999001) — the documented
	; R3 stopgap until v-pkg can ship a permanent-namespace file number (coverage
	; analysis item B.2-b). $$query reads through the VSLFS finder ($$list, the
	; remediation plan's R-EXT-6) and never walks the data global directly — the
	; VSLFS seam owns all record access.
	;
	; *** ERROR CONTRACT — loud, never a silent lost record ***
	; A FileMan write failure surfaces from VSLFS as ,U-VSL-FS-DIERR,; VSLLOG
	; catches it and re-raises a clean ,U-VSL-LOG-WRITE, $ECODE, carrying the
	; underlying VSLFS detail in ^TMP($job,"vsllog","err") for $$lastError. The
	; "audit log must never silently drop a record" goal (§6.2): a sink failure is
	; loud, not swallowed. Reads of an absent record return "" (as VSLFS reads do).
	;
	; ICR: VSLLOG makes ONE direct L4 call — $$NOW^XLFDT (ICR #10103, Supported,
	; the FileMan-internal current date/time for the TIMESTAMP field), declared on
	; write. Every FileMan record I/O is inside VSLFS (declared there); the rest
	; is v->v (VSLFS) + v->m (STD*). No direct global access.
	;
	quit
	;
	; ---------- the dedicated audit file ----------
	;
auditFile()	; The dedicated VSL AUDIT FileMan file number (single source of truth).
	; doc: @returns          numeric  the VSL AUDIT file number (#999001)
	; doc: @example   do eq^STDASSERT(.pass,.fail,$$auditFile^VSLLOG(),999001,"the dedicated VSL AUDIT file number")
	quit 999001
	;
	; ---------- the audit sink, bound to FileMan via VSLFS (v->v) ----------
	;
write(event,detail,duz,host)	; File one structured audit record; return the resolved IENS, else raise.
	; doc: @param   event    string   short event name (the .01; 1-30 chars)
	; doc: @param   detail   string   free-text detail (filed only when non-empty)
	; doc: @param   duz      numeric  acting principal #200 IEN; defaults to +$GET(DUZ); 0 = system
	; doc: @param   host     string   originating host/$IO; defaults to $IO (filed only when non-empty)
	; doc: @returns          string   the resolved IENS of the new audit record
	; doc: @raises  U-VSL-LOG-WRITE  the FileMan write failed (detail in $$lastError)
	; doc: @icr 10103 @call $$NOW^XLFDT @status Supported @custodian XU @source XU/krn_8_0_dg_xlf_fl_ug#nowxlfdt-current-date-and-time-va-fileman-format
	; doc: @illustrative  files a real structured FileMan record into the dedicated VSL AUDIT file (#999001) — a live mutation needing the DD resident + teardown, not a safe read-only one-liner; exercised on live VistA by VSLLOGTST tWriteReadRoundtrip
	; Every $$set^VSLFS is called DIRECTLY in this frame (not via a helper extrinsic)
	; so the flag-based $etrap behaves as the proven VSLLOG idiom: a VSLFS DIERR
	; flips ok, the `if ok` guards skip the rest, and raiseWrite maps it to a clean
	; ,U-VSL-LOG-WRITE,. An intermediate `set x=$$helper(...)` would, on IRIS, raise
	; a secondary fault when the trap unwinds the helper with no return value.
	new $etrap,file,iens,ok,u,h,x
	set ok=1,h=""
	set $etrap="set ok=0,$ecode="""" quit"
	set file=$$auditFile()
	set iens=$$set^VSLFS(file,"+1,",".01",event)
	if ok set x=$$set^VSLFS(file,iens,"1",$$NOW^XLFDT)
	if ok set u=$select($data(duz):+duz,1:+$get(DUZ)),x=$$set^VSLFS(file,iens,"2",u)
	if ok set h=$extract($select($get(host)'="":host,1:$io),1,80)
	if ok,h'="" set x=$$set^VSLFS(file,iens,"3",h)
	if ok,$get(detail)'="" set x=$$set^VSLFS(file,iens,"4",detail)
	if ok quit iens
	set $etrap="" do raiseWrite quit ""
	;
raiseWrite	; (private) map a downstream VSLFS fault to a loud ,U-VSL-LOG-WRITE,.
	new detail
	set detail=$$oneLine($$lastError^VSLFS())
	set ^TMP($job,"vsllog","err")="write: "_$select(detail'="":detail,1:"FileMan write failed")
	set $ecode=",U-VSL-LOG-WRITE,"
	quit
	;
oneLine(s)	; (private) collapse CR/LF in `s` to spaces — an audit detail is one line.
	; A multi-line FileMan DIERR (TEXT lines joined by $C(10) in VSLFS) would put a
	; raw newline into the audit record and corrupt the IRIS driver's session frame;
	; keep the composed detail a single line.
	quit $translate(s,$char(13)_$char(10),"  ")
	;
read(iens,rec)	; Read the audit record's typed fields into rec(); return the EVENT (.01), else "".
	; doc: @param   iens     string   IENS of the audit record
	; doc: @param   rec      array    (by ref) filled: rec("event"|"timestamp"|"user"|"host"|"detail")
	; doc: @returns          string   the stored EVENT (.01), or "" if the record is absent
	; doc: @illustrative  reads a structured record back from the dedicated VSL AUDIT file (#999001); needs a record present, not a safe read-only one-liner; exercised on live VistA by VSLLOGTST tWriteReadRoundtrip
	new file
	set file=$$auditFile()
	set rec("event")=$$get^VSLFS(file,iens,".01","")
	set rec("timestamp")=$$get^VSLFS(file,iens,"1","")
	set rec("user")=$$get^VSLFS(file,iens,"2","")
	set rec("host")=$$get^VSLFS(file,iens,"3","")
	set rec("detail")=$$get^VSLFS(file,iens,"4","")
	quit rec("event")
	;
query(out,event,fromDt,toDt)	; Filter audit records by event and/or FileMan date range into out("ien,")=event; return the count.
	; doc: @param   out      array    (by ref) set out("ien,")=event for each matching record
	; doc: @param   event    string   exact event (.01) to match; "" = any event
	; doc: @param   fromDt   numeric  inclusive lower bound on TIMESTAMP (FileMan internal date); "" = no lower bound
	; doc: @param   toDt     numeric  inclusive upper bound on TIMESTAMP (FileMan internal date); "" = no upper bound
	; doc: @returns          numeric  the number of matching records
	; doc: @illustrative  filters real audit records in the dedicated VSL AUDIT file (#999001) via the VSLFS finder; needs records present, not a safe read-only one-liner; exercised on live VistA by VSLLOGTST tQueryFilters
	new file,all,iens,cur,n,ev,ts,junk
	set file=$$auditFile()
	set junk=$$list^VSLFS(file,.all,"B")
	set n=0,iens=$order(all(""))
	for  quit:iens=""  do
	. set cur=iens,iens=$order(all(iens))
	. set ev=$$get^VSLFS(file,cur,".01","")
	. quit:(event'="")&(ev'=event)
	. set ts=$$get^VSLFS(file,cur,"1","","I")
	. quit:(fromDt'="")&(ts<fromDt)
	. quit:(toDt'="")&(ts>toDt)
	. set out(cur)=ev,n=n+1
	quit n
	;
lastError()	; The last VSLLOG error message (the composed FileMan detail).
	; doc: @returns          string   ^TMP($job,"vsllog","err"), or "" if none
	; doc: @example   new prior,r set prior=$get(^TMP($job,"vsllog","err")),^TMP($job,"vsllog","err")="write: x" set r=$$lastError^VSLLOG() set ^TMP($job,"vsllog","err")=prior do eq^STDASSERT(.pass,.fail,r,"write: x","lastError returns the composed FileMan detail")
	quit $get(^TMP($job,"vsllog","err"))
