VSLFS	; v-stdlib — VistA FileMan storage adapter (FileMan DBS record store).
	; doc: @exrun live
	; doc: @exsafe transactional
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positives: the analyser reads the FileMan DBS I/O arrays
	; (FDA / IEN / ERR, written by the called DBS routine by-reference) as
	; locals-before-def; they are the documented GETS/UPDATE/FILE convention.
	; Same suppression as VSLIO/STDNET.
	;
	; Binds the MSL storage seam (STDKV, S1) to VistA's FileMan Database Server
	; (DBS) API: a record store addressed by (file, iens, field). It exposes the
	; same four-verb signature as STDKV — $$set/$$get/$$exists/$$kill — backed by
	; FileMan DBS calls, never direct global access (architecture §3.2). The
	; adapter contains ONLY the VistA binding; any non-FileMan logic stays in the
	; MSL seam, called up (m/v waterline §9 no-duplication).
	;
	; Public API (the handle is a FileMan IENS; values are field values):
	;   $$set^VSLFS(file,iens,field,value) — file a field INTERNAL (UPDATE^DIE, no
	;                                         transform); "+1," adds -> resolved IENS
	;   $$get^VSLFS(file,iens,field,default,flags)— read a field ($$GET1^DIQ); default
	;                                         is the EXTERNAL value, flags "I" the internal
	;   $$gets^VSLFS(file,iens,fields,.out,flags)— read many fields in one call (GETS^DIQ)
	;                                         -> out(field)=value; returns the count
	;   $$exists^VSLFS(file,iens)           — 1 iff the record exists
	;   $$kill^VSLFS(file,iens)             — delete the record (FILE^DIE, .01="@")
	;   $$find^VSLFS(file,value,index)      — IENS of the unique `index` match ($$FIND1^DIC)
	;   $$list^VSLFS(file,.out,index)       — list every record's IENS into out (LIST^DIC)
	;   $$lastError^VSLFS()                 — last FileMan DIERR detail, else ""
	;
	; *** ERROR CONTRACT — loud, never a silent wrong value ***
	; A FileMan DIERR on a write maps to a clean ,U-VSL-FS-DIERR, $ECODE, with the
	; DIERR text composed into ^TMP($job,"vslfs","err") for $$lastError. Reads of
	; an absent record/field are NOT errors — $$get returns the default and
	; $$exists returns 0 (the STDKV "absent -> default" semantics). Every DBS call
	; passes an explicit MSG_ROOT ("ERR") so errors land in this adapter's own
	; array, never the shared ^TMP("DIERR",$J).
	;
	; ICR note: the FileMan DBS API is the public DBS programmer API (FileMan
	; Developer's Guide, custodian DI). The DBIA/ICR *number* is notional — a
	; manually-curated FORUM list, not enforced programmatically — so each call is
	; tagged `@icr DBS` (the notional marker), with a real @status/@custodian/
	; @source. See docs/memory notional-dbia-not-a-blocker + plan §5.4.
	;
	quit
	;
	; ---------- the storage seam, bound to FileMan DBS (4 verbs) ----------
	;
set(file,iens,field,value)	; File `value` into (file,iens,field); return the resolved IENS, else raise.
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   iens     string   IENS; "+1," (etc.) adds a new record
	; doc: @param   field    string   field number within the file
	; doc: @param   value    string   the FileMan-INTERNAL value to file (see note)
	; doc: @returns          string   the resolved IENS on success (the new IENS for an add)
	; doc: @raises  U-VSL-FS-DIERR  a FileMan DIERR (detail in $$lastError)
	; doc: UPDATE^DIE is called with NO "E" flag, so `value` is filed as the FileMan
	; doc: INTERNAL value and NO input transform runs. For transformed fields (DATE,
	; doc: POINTER, SET OF CODES) pass the internal form (e.g. an $$NOW^XLFDT date),
	; doc: not the external string; .01 free text is transform-invariant either way.
	; doc: Asymmetry to know: $$set files INTERNAL but $$get defaults to EXTERNAL — to
	; doc: round-trip a transformed field, read it back with $$get(...,"I").
	; doc: @icr DBS @call UPDATE^DIE @status Supported @custodian DI @source DI/fm22_2dg#updatedie-updater
	; doc: @illustrative  a successful add (and its DIERR-raise path) is a live FileMan mutation; exercised by tests/VSLFSTST.m tCreateGetRoundtrip, not a safe read-only one-liner
	new FDA,IEN,ERR
	set FDA(file,iens,field)=value
	do UPDATE^DIE("","FDA","IEN","ERR")
	if $data(ERR("DIERR")) do raiseDierr("set",.ERR) quit ""
	quit $$resolveIens(iens,.IEN)
	;
get(file,iens,field,default,flags)	; Read (file,iens,field) via $$GET1^DIQ; return value, else `default`.
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   iens     string   IENS of the record
	; doc: @param   field    string   field number
	; doc: @param   default  string   value returned when the field/record is unset
	; doc: @param   flags    string   $$GET1^DIQ flags: "" external (default), "I" internal
	; doc: @returns          string   the field value (external, or internal if flags["I"]), or `default`
	; doc: Default ("" flags) reads the EXTERNAL value; "I" reads the INTERNAL value.
	; doc: Since $$set files INTERNAL, read a transformed field back with "I" to get
	; doc: exactly what was filed (the external default applies the output transform).
	; doc: @icr DBS @call $$GET1^DIQ @status Supported @custodian DI @source DI/fm22_2dg#get1diq-data-retriever-single-field
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do true^STDASSERT(.pass,.fail,$$get^VSLFS(200,"1,",".01","")'="","get: #200 IEN 1 (.01) reads a non-empty name")
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$get^VSLFS(200,"999999999,",".01","MISS"),"MISS","get: an absent record returns the default")
	new val,ERR
	set val=$$GET1^DIQ(file,iens,field,$get(flags),"","ERR")
	if $data(ERR("DIERR")) quit default
	quit $select(val="":default,1:val)
	;
gets(file,iens,fields,out,flags)	; Read several fields of one record in a single DBS round-trip (GETS^DIQ); count into out.
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   iens     string   IENS of the record (e.g. "1,")
	; doc: @param   fields   string   GETS field spec: ".01;.02" list, "M:N" range, or "*" (all top-level); default "*"
	; doc: @param   out      array    (by ref) set out(field)=value for each top-level field read (killed first)
	; doc: @param   flags    string   optional; "I" internal values (default external). Do NOT pass "R" (it renames the subscripts).
	; doc: @returns          numeric  the number of top-level fields placed into out
	; doc: @raises  U-VSL-FS-DIERR  a FileMan DIERR (detail in $$lastError)
	; doc: One round-trip for a whole record vs N $$get calls. Reads SCALAR top-level fields;
	; doc: word-processing and sub-multiple fields are out of scope (scalar flatten only).
	; doc: @icr 2056 @call GETS^DIQ @status Supported @custodian DI @source DI/fm22_2dg#getsdiq-data-retriever-multiple-fields
	; doc: @illustrative  reads real FileMan records; needs a throwaway test DD with records — exercised on live VistA by tests/VSLFSTST.m tGetsMultiField
	new FDA,ERR,f,cnt,fl,leaf
	kill out
	set fl=$get(flags),leaf=$select(fl["I":"I",fl["E":"E",1:"")
	do GETS^DIQ(file,iens,$get(fields,"*"),fl,"FDA","ERR")
	if $data(ERR("DIERR")) do raiseDierr("gets",.ERR) quit 0
	set cnt=0,f=""
	for  set f=$order(FDA(file,iens,f)) quit:f=""  do
	. set out(f)=$select(leaf="":$get(FDA(file,iens,f)),1:$get(FDA(file,iens,f,leaf)))
	. set cnt=cnt+1
	quit cnt
	;
exists(file,iens)	; Return 1 iff record (file,iens) exists (its .01 reads without a DIERR).
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   iens     string   IENS of the record
	; doc: @returns          bool     1 iff the record exists; 0 otherwise
	; doc: @icr DBS @call $$GET1^DIQ @status Supported @custodian DI @source DI/fm22_2dg#get1diq-data-retriever-single-field
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(200,"1,"),1,"exists: #200 IEN 1 (postmaster) exists")
	; doc: @example   set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(200,"999999999,"),0,"exists: an absent record returns 0")
	new val,ERR
	set val=$$GET1^DIQ(file,iens,".01","","","ERR")
	if $data(ERR("DIERR")) quit 0
	quit $select(val="":0,1:1)
	;
kill(file,iens)	; Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1.
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   iens     string   IENS of the record to delete
	; doc: @returns          bool     1 always (idempotent — a failed delete records a DIERR, never raises, unlike $$set)
	; doc: This swallow-vs-raise asymmetry with $$set is deliberate (a delete is
	; doc: idempotent). A caller that needs delete-or-fail semantics must check
	; doc: $$lastError^VSLFS() after $$kill — a non-empty result means the FILE^DIE hit a DIERR.
	; doc: @icr DBS @call FILE^DIE @status Supported @custodian DI @source DI/fm22_2dg#filedie-filer
	; doc: @illustrative  deletes a real FileMan record (a persistent mutation); exercised by tests/VSLFSTST.m tExistsThenKill, not a safe read-only one-liner
	new FDA,ERR
	set FDA(file,iens,".01")="@"
	do FILE^DIE("","FDA","ERR")
	if $data(ERR("DIERR")) do stashDierr("kill",.ERR)
	quit 1
	;
find(file,value,index)	; The IENS of the UNIQUE record whose `index` lookup equals `value`, else "".
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   value    string   the lookup value to match (exact)
	; doc: @param   index    string   the cross-reference to search (default "B")
	; doc: @returns          string   the IENS ("ien,") of the single match, else "" (absent or ambiguous)
	; doc: @icr DBS @call $$FIND1^DIC @status Supported @custodian DI @source DI/fm22_2dg#find1dic-finder-single-record
	; doc: @illustrative  resolves a record by an indexed value; a meaningful match needs known live data (or a throwaway test DD) — exercised on live VistA by tests/VSLFSTST.m tFindByName
	new y,ERR
	set y=$$FIND1^DIC(file,"","X",value,$get(index,"B"),"","ERR")
	quit $select(+y>0:y_",",1:"")
	;
list(file,out,index)	; List the IENS of every record (via LIST^DIC) into out("ien,"); return the count.
	; doc: @param   file     numeric  FileMan file number
	; doc: @param   out      array    (by ref) set out("ien,")="" for each record found
	; doc: @param   index    string   traversal cross-reference (default "B")
	; doc: @returns          numeric  the number of records listed
	; doc: @raises  U-VSL-FS-DIERR  a FileMan DIERR (detail in $$lastError)
	; doc: @icr DBS @call LIST^DIC @status Supported @custodian DI @source DI/fm22_2dg#listdic-lister
	; doc: @illustrative  lists real FileMan records; demonstrating it needs a throwaway test DD (#999000 ZZVSLFS) with records, not a safe read-only one-liner — see tests/VSLFSTST.m tListAllRecords
	new ERR,cnt,seq,ien
	kill ^TMP("DILIST",$job)
	do LIST^DIC(file,"","@;.01","","*","","",$get(index,"B"),"","","","ERR")
	if $data(ERR("DIERR")) do raiseDierr("list",.ERR) quit 0
	set cnt=+$get(^TMP("DILIST",$job,0))
	set seq=$order(^TMP("DILIST",$job,2,""))
	for  quit:seq=""  do
	. set ien=$get(^TMP("DILIST",$job,2,seq))
	. if ien'="" set out(ien_",")=""
	. set seq=$order(^TMP("DILIST",$job,2,seq))
	kill ^TMP("DILIST",$job)
	quit cnt
	;
lastError()	; The last VSLFS error message (the composed FileMan DIERR detail).
	; doc: @returns          string   ^TMP($job,"vslfs","err"), or "" if none
	; doc: @illustrative  $$lastError is exercised by the DIERR-path assertions in tests/VSLFSTST.m; the inline ^TMP round-trip duplicated that canonical check
	quit $get(^TMP($job,"vslfs","err"))
	;
	; ---------- internals ----------
	;
raiseDierr(who,ERR)	; Stash the DIERR detail, then raise the clean ,U-VSL-FS-DIERR,.
	do stashDierr(who,.ERR)
	set $ecode=",U-VSL-FS-DIERR,"
	quit
	;
stashDierr(who,ERR)	; Compose the FileMan DIERR text into ^TMP($job,"vslfs","err").
	new m,nl,seq
	set nl=$char(10)
	set m=who_": FileMan DIERR ("_$get(ERR("DIERR"))_")"
	set seq=$order(ERR("DIERR",""))
	for  quit:seq=""  do
	. do:seq=+seq addText(seq,.ERR,.m,nl)
	. set seq=$order(ERR("DIERR",seq))
	set ^TMP($job,"vslfs","err")=m
	quit
	;
addText(seq,ERR,m,nl)	; Append every TEXT line of DIERR `seq` to `m` (by ref).
	new ln
	set ln=$order(ERR("DIERR",seq,"TEXT",""))
	for  quit:ln=""  do
	. set m=m_nl_$get(ERR("DIERR",seq,"TEXT",ln))
	. set ln=$order(ERR("DIERR",seq,"TEXT",ln))
	quit
	;
resolveIens(iens,IEN)	; Resolve a "+n," add-node IENS to its real IENS; else echo iens.
	; UPDATE^DIE returns the new internal entry number for a "+n," placeholder in
	; IEN(n); a non-placeholder IENS files in place and is returned unchanged.
	new n
	if $extract(iens,1)'="+" quit iens
	set n=+$piece($extract(iens,2,$length(iens)),",")
	quit $get(IEN(n))_","
