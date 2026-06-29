VSLLOGTST ; v-stdlib — VSLLOG (dedicated VistA FileMan audit-sink) test suite.
 ; Exercises VSLLOG against a live VistA's FileMan DBS API, over the driver
 ; stack only (m/v waterline — the ONLY path):
 ;   m test --engine ydb  --docker vehu     --chset m \
 ;     --routines src --routines <m-stdlib>/src tests/VSLLOGTST.m
 ;   m test --engine iris --docker foia-t12 --namespace VISTA \
 ;     --routines src --routines <m-stdlib>/src tests/VSLLOGTST.m
 ;
 ; VSLLOG is the audit sink: it OWNS a dedicated VistA FileMan file — VSL AUDIT
 ; (#999001, data global ^DIZ(999001,) — and writes a STRUCTURED audit record by
 ; REUSING VSLFS (v->v composition; it does NOT re-bind the FileMan DBS) and maps
 ; a write failure to a clean ,U-VSL-LOG-WRITE, $ECODE. The record's typed fields
 ; are .01 EVENT (free text), TIMESTAMP (date/time, filed as "NOW"), USER NUMBER
 ; (numeric DUZ; 0 = system context), HOST (free text $IO), and DETAIL (free
 ; text). USER NUMBER is a plain numeric, NOT a #200 pointer, so a system-context
 ; record (DUZ 0) files cleanly with no dependency on a populated NEW PERSON.
 ;
 ; The VSL AUDIT DD must be RESIDENT before this suite runs — installed from the
 ; VSL KIDS build via `v pkg install dist/kids/VSL.kids --engine <e>` (the org
 ; bespoke-installer ban: a real KIDS install, never a hand-rolled DD). Each test
 ; files a throwaway ZZ-event record and removes it (via VSLFS) in teardown.
 new pass,fail
 do start^STDASSERT(.pass,.fail)
 ;
 do tWriteReadRoundtrip(.pass,.fail)
 do tHostTruncatedTo80(.pass,.fail)
 do tSystemContextWrites(.pass,.fail)
 do tWriteFailureIsLoud(.pass,.fail)
 do tQueryFilters(.pass,.fail)
 do tQueryVolumeExactCount(.pass,.fail)
 ;
 do report^STDASSERT(pass,fail)
 quit
 ;
tWriteReadRoundtrip(pass,fail) ;@TEST "$$write files a structured audit record and $$read returns its typed fields"
 new event,detail,iens,rec
 do setup()
 set event="ZZVSLLOG-LOGIN"
 set detail="USER=1 JOB="_$job
 set iens=$$write^VSLLOG(event,detail,1,"TEST.HOST")
 do true^STDASSERT(.pass,.fail,iens'="","audit record written (got a resolved IENS)")
 quit:iens=""
 do eq^STDASSERT(.pass,.fail,$$read^VSLLOG(iens,.rec),event,"$$read returns the event (.01) and fills rec()")
 do eq^STDASSERT(.pass,.fail,$get(rec("event")),event,"rec(event) round-trips byte-identical")
 do eq^STDASSERT(.pass,.fail,$get(rec("detail")),detail,"rec(detail) round-trips byte-identical")
 do eq^STDASSERT(.pass,.fail,$get(rec("user")),1,"rec(user) is the acting DUZ")
 do eq^STDASSERT(.pass,.fail,$get(rec("host")),"TEST.HOST","rec(host) round-trips")
 do true^STDASSERT(.pass,.fail,$get(rec("timestamp"))'="","rec(timestamp) is populated (generated)")
 do teardown(iens)
 quit
 ;
tHostTruncatedTo80(pass,fail) ;@TEST "$$write truncates an over-long HOST to the 80-char field width"
 ; Boundary: the HOST field (#999001,.03) is free text, max 80; $$write applies
 ; $extract(...,1,80) before filing. A 100-char host must store as its first 80.
 new iens,rec,longhost,exp,x
 do setup()
 set longhost=$translate($justify("",100)," ","H") ; 100 'H' characters
 set exp=$extract(longhost,1,80)
 set iens=$$write^VSLLOG("ZZVSLLOG-TRUNC","d",1,longhost)
 do true^STDASSERT(.pass,.fail,iens'="","over-long-host record written")
 quit:iens=""
 set x=$$read^VSLLOG(iens,.rec)
 do eq^STDASSERT(.pass,.fail,$length($get(rec("host"))),80,"HOST stored at the 80-char field width (truncated from 100)")
 do eq^STDASSERT(.pass,.fail,$get(rec("host")),exp,"HOST is the first 80 chars of the over-long input")
 do teardown(iens)
 quit
 ;
tSystemContextWrites(pass,fail) ;@TEST "$$write files a system-context record (DUZ 0) — USER NUMBER is numeric, not a #200 pointer"
 new iens,rec,x
 do setup()
 set iens=$$write^VSLLOG("ZZVSLLOG-SYS","boot",0,"TEST.HOST")
 do true^STDASSERT(.pass,.fail,iens'="","system-context record written (DUZ 0 files into the numeric field)")
 quit:iens=""
 set x=$$read^VSLLOG(iens,.rec)
 do eq^STDASSERT(.pass,.fail,$get(rec("user")),0,"rec(user) is 0 for system context")
 do teardown(iens)
 quit
 ;
tWriteFailureIsLoud(pass,fail) ;@TEST "a FileMan write failure maps to a clean ,U-VSL-LOG-..., $ECODE with detail in $$lastError"
 do setup()
 ; an empty event (.01 is required on a new FileMan entry) -> DIERR -> loud
 do raises^STDASSERT(.pass,.fail,"set x=$$write^VSLLOG("""",""d"",1,""h"")",",U-VSL-LOG-WRITE,","$$write of a record with an empty .01 raises exactly ,U-VSL-LOG-WRITE,")
 do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped write raise (clean unwind)")
 do true^STDASSERT(.pass,.fail,$$lastError^VSLLOG()'="","lastError carries the underlying FileMan detail")
 quit
 ;
tQueryFilters(pass,fail) ;@TEST "$$query filters audit records by exact event and by FileMan date range"
 new i1,i2,i3,out,cnt,today
 do setup()
 set today=$$DT^XLFDT
 set i1=$$write^VSLLOG("ZZQRY-A","one",1,"H")
 set i2=$$write^VSLLOG("ZZQRY-A","two",2,"H")
 set i3=$$write^VSLLOG("ZZQRY-B","three",1,"H")
 quit:(i1="")!(i2="")!(i3="")
 kill out set cnt=$$query^VSLLOG(.out,"ZZQRY-A","","")
 do true^STDASSERT(.pass,.fail,$data(out(i1))&$data(out(i2)),"event filter returns both ZZQRY-A records")
 do true^STDASSERT(.pass,.fail,'$data(out(i3)),"event filter excludes the ZZQRY-B record")
 kill out set cnt=$$query^VSLLOG(.out,"",today,"")
 do true^STDASSERT(.pass,.fail,$data(out(i1))&$data(out(i3)),"date-from (today) includes today's records")
 kill out set cnt=$$query^VSLLOG(.out,"",today+10000,"")
 do true^STDASSERT(.pass,.fail,'$data(out(i1)),"a future date-from excludes today's records")
 do teardown(i1)
 do teardown(i2)
 do teardown(i3)
 quit
 ;
tQueryVolumeExactCount(pass,fail) ;@TEST "$$query returns the exact count across many matching records, no DILIST residue (volume)"
 ; Volume + residue: file several records under one unique event, confirm $$query
 ; returns exactly that many and (via $$list) leaves no ^TMP(DILIST) scratch.
 new i,event,ids,out,out2,n,nany
 do setup()
 kill ^TMP("DILIST",$job)
 set event="ZZVSLLOG-VOL"_$job
 for i=1:1:5 set ids(i)=$$write^VSLLOG(event,"d"_i,1,"H")
 ; date bounds omitted -> the optional fromDt/toDt formals must not UNDEF
 set n=$$query^VSLLOG(.out,event)
 do eq^STDASSERT(.pass,.fail,n,5,"$$query returns the exact count (5) for the unique event (fromDt/toDt omitted)")
 ; all optional args omitted -> "any event", must include the 5 filed (no UNDEF)
 set nany=$$query^VSLLOG(.out2)
 do true^STDASSERT(.pass,.fail,nany'<5,"$$query with all optional args omitted (any event) returns >= the 5 filed")
 do true^STDASSERT(.pass,.fail,'$data(^TMP("DILIST",$job)),"$$query (via $$list) leaves no ^TMP(DILIST,$job) residue")
 for i=1:1:5 do teardown(ids(i))
 quit
 ;
 ; ---------- fixtures ----------
 ;
setup() ; FileMan programmer context for the dedicated VSL AUDIT file (#999001).
 set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
 quit
 ;
teardown(iens) ; Remove the throwaway audit record if it still exists (via VSLFS).
 new file,x
 quit:iens=""
 set file=$$auditFile^VSLLOG()
 quit:'$$exists^VSLFS(file,iens)
 set x=$$kill^VSLFS(file,iens)
 quit
