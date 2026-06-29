VSLFSTST ; v-stdlib — VSLFS (FileMan DBS storage adapter) test suite.
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
 do tFindAmbiguousIsEmpty(.pass,.fail)
 do tListAllRecords(.pass,.fail)
 do tListVolumeNoResidue(.pass,.fail)
 do tGetsMultiField(.pass,.fail)
 do tGetsDierrIsLoud(.pass,.fail)
 do tInternalFilingRoundtrip(.pass,.fail)
 do tCaretSilentlyTruncates(.pass,.fail)
 do tOverWidthSilentlyStored(.pass,.fail)
 do tCaretSilentlyCorruptsSibling(.pass,.fail)
 ;
 do report^STDASSERT(pass,fail)
 quit
 ;
tCreateGetRoundtrip(pass,fail) ;@TEST "$$set creates a record and $$get reads its field back byte-identical"
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
tExistsThenKill(pass,fail) ;@TEST "$$exists is true after create; $$kill removes the record so $$exists is false and $$get returns default"
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
tDierrIsLoud(pass,fail) ;@TEST "a FileMan DIERR maps to a clean ,U-VSL-FS-..., $ECODE with the detail in $$lastError"
 new file
 do setup(.file)
 do raises^STDASSERT(.pass,.fail,"set x=$$set^VSLFS(99999999,""+1,"","".01"",""ZZ"")",",U-VSL-FS-DIERR,","$$set into a bogus file raises exactly ,U-VSL-FS-DIERR,")
 do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped set raise (clean unwind)")
 do true^STDASSERT(.pass,.fail,$$lastError^VSLFS()'="","lastError carries the FileMan DIERR detail")
 quit
 ;
tFindByName(pass,fail) ;@TEST "$$find returns the IENS of a uniquely-named record by the B index, and "" when absent"
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
tFindAmbiguousIsEmpty(pass,fail) ;@TEST "$$find returns empty when the lookup value is ambiguous (>1 record shares the .01)"
 ; Boundary: $$FIND1^DIC resolves a UNIQUE match only; >1 match is ambiguous and
 ; yields "" (not the first IEN). File two records under the same .01 NAME, confirm
 ; both exist distinctly, then $$find by that name must be "".
 new file,name,i1,i2,found
 do setup(.file)
 set name="ZZVSLFS "_$job_"DUP"
 set i1=$$set^VSLFS(file,"+1,",".01",name)
 set i2=$$set^VSLFS(file,"+1,",".01",name)
 quit:(i1="")!(i2="")
 do true^STDASSERT(.pass,.fail,i1'=i2,"two distinct records were filed under the same .01 NAME")
 set found=$$find^VSLFS(file,name,"B")
 do eq^STDASSERT(.pass,.fail,found,"","$$find returns empty for an ambiguous (multi-match) lookup")
 do teardown(file,i1)
 do teardown(file,i2)
 quit
 ;
tListAllRecords(pass,fail) ;@TEST "$$list returns the IENS of every record (the two just created are present)"
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
tListVolumeNoResidue(pass,fail) ;@TEST "$$list counts every record and leaves no ^TMP(DILIST) scratch residue (volume)"
 ; Volume + residue: file several throwaway records, confirm $$list returns them
 ; all (count integrity) and kills its ^TMP("DILIST",$job) scratch on the way out.
 new file,i,nm,ids,out,cnt,missing
 do setup(.file)
 kill ^TMP("DILIST",$job)
 for i=1:1:5 set nm="ZZVSLFS "_$job_"V"_i,ids(i)=$$set^VSLFS(file,"+1,",".01",nm)
 set cnt=$$list^VSLFS(file,.out,"B")
 set missing=0 for i=1:1:5 if '$data(out(ids(i))) set missing=missing+1
 do eq^STDASSERT(.pass,.fail,missing,0,"every filed record appears in $$list output (count integrity)")
 do true^STDASSERT(.pass,.fail,cnt>=5,"$$list count covers at least the 5 filed records")
 do true^STDASSERT(.pass,.fail,'$data(^TMP("DILIST",$job)),"$$list leaves no ^TMP(DILIST,$job) scratch residue")
 for i=1:1:5 do teardown(file,ids(i))
 quit
 ;
tGetsMultiField(pass,fail) ;@TEST "$$gets reads multiple fields of one record in a single DBS round-trip (GETS^DIQ)"
 ; Whole-record read: file a #999001 VSL AUDIT record with .01 + HOST(field 3), then read
 ; ALL top-level fields in ONE call and confirm they flatten into out(field)=value (vs N
 ; single-field $$get round-trips). Self-restoring: the throwaway record is killed.
 new file,iens,nm,out,cnt,x
 do setup(.file)
 set file=999001
 set nm="ZZVSLFS-GETS "_$job
 set iens=$$set^VSLFS(file,"+1,",".01",nm)
 do true^STDASSERT(.pass,.fail,iens'="","VSL AUDIT record created for the gets probe")
 quit:iens=""
 set x=$$set^VSLFS(file,iens,"3","HOST.X")
 set cnt=$$gets^VSLFS(file,iens,"*",.out)
 do true^STDASSERT(.pass,.fail,cnt>=2,"$$gets returned at least the 2 set fields (.01 + HOST) in one call")
 do eq^STDASSERT(.pass,.fail,$get(out(".01")),nm,"$$gets flattened the .01 NAME into out(.01)")
 do eq^STDASSERT(.pass,.fail,$get(out(3)),"HOST.X","$$gets flattened field 3 (HOST) into out(3)")
 set x=$$kill^VSLFS(file,iens)
 quit
 ;
tGetsDierrIsLoud(pass,fail) ;@TEST "$$gets on a bogus file raises a clean ,U-VSL-FS-DIERR, with detail in $$lastError"
 new file
 do setup(.file)
 do raises^STDASSERT(.pass,.fail,"set x=$$gets^VSLFS(99999999,""1,"",""*"",.zz)",",U-VSL-FS-DIERR,","$$gets on a bogus file raises exactly ,U-VSL-FS-DIERR,")
 do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped gets raise (clean unwind)")
 do true^STDASSERT(.pass,.fail,$$lastError^VSLFS()'="","lastError carries the FileMan DIERR detail")
 quit
 ;
tInternalFilingRoundtrip(pass,fail) ;@TEST "$$set files the INTERNAL value (no transform): $$get ""I"" round-trips it; the external default differs (a transform applies)"
 ; Proves the internal-vs-external contract that the transform-invariant #999000
 ; .01 cannot. Uses the resident VSL AUDIT file (#999001) for its DATE field (#1).
 ; Self-restoring: the throwaway audit record is killed at the end.
 new file,iens,fmdt,gi,ge,x
 do setup(.file)
 set file=999001
 set iens=$$set^VSLFS(file,"+1,",".01","ZZVSLFS-ITEST "_$job)
 do true^STDASSERT(.pass,.fail,iens'="","VSL AUDIT record created for the internal-filing probe")
 quit:iens=""
 set fmdt=3250115   ; FileMan-internal date = 15 Jan 2025
 set x=$$set^VSLFS(file,iens,"1",fmdt)
 set gi=$$get^VSLFS(file,iens,"1","","I")
 set ge=$$get^VSLFS(file,iens,"1","")
 do eq^STDASSERT(.pass,.fail,gi,fmdt,"$$set filed the INTERNAL date verbatim; $$get ""I"" reads it back unchanged")
 do true^STDASSERT(.pass,.fail,ge'="","$$get default returns the external form (non-empty)")
 do true^STDASSERT(.pass,.fail,ge'=gi,"external read differs from internal — proves $$set ran NO transform (filed internal)")
 set x=$$kill^VSLFS(file,iens)
 quit
 ;
tCaretSilentlyTruncates(pass,fail) ;@TEST "ADVERSARIAL (F1): a ^-bearing value files into a LAST-PIECE free-text field WITHOUT raising; $$get truncates it at the first ^ — silent data loss, no guard"
 ; Internal filing (UPDATE^DIE, no transform) does NOT reject the ^ delimiter. For
 ; #999000 .01 (the only piece of its node) FileMan stores "A^B^C" with no DIERR, but
 ; $$GET1^DIQ reads back only the first ^-piece ("A"). Confirmed on YDB+IRIS. The
 ; hazard: callers must not pass ^-bearing values to internal filing (see VSLFS
 ; header "INTERNAL FILING HAZARDS"). See tCaretSilentlyCorruptsSibling for the
 ; severe form (a ^ silently overwriting an adjacent field that shares the node).
 new file,iens,got,raised,$etrap
 do setup(.file)
 set raised=0,$etrap="set raised=1,$ecode="""" quit"
 set iens=$$set^VSLFS(file,"+1,",".01","A^B^C")
 set $etrap=""
 do false^STDASSERT(.pass,.fail,raised,"a ^-bearing value files with NO raise (silent — internal filing does not guard ^)")
 quit:iens=""
 set got=$$get^VSLFS(file,iens,".01","MISS")
 do eq^STDASSERT(.pass,.fail,got,"A","$$get returns only the first ^-piece (silent truncation of A^B^C to A)")
 do teardown(file,iens)
 quit
 ;
tOverWidthSilentlyStored(pass,fail) ;@TEST "ADVERSARIAL (F1): a value wider than the field's DD width files WITHOUT raising and reads back oversize — internal filing bypasses the width transform"
 ; UPDATE^DIE with no "E" flag runs no input transform, so the 30-char-width #999000
 ; .01 accepts a longer value and $$get reads it back over width. Confirmed YDB+IRIS.
 new file,iens,got,raised,v,$etrap
 do setup(.file)
 set v="ZZADV"_$job_"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ; > 30 chars
 set raised=0,$etrap="set raised=1,$ecode="""" quit"
 set iens=$$set^VSLFS(file,"+1,",".01",v)
 set $etrap=""
 do false^STDASSERT(.pass,.fail,raised,"an over-width value files with NO raise (width transform bypassed)")
 quit:iens=""
 set got=$$get^VSLFS(file,iens,".01","")
 do true^STDASSERT(.pass,.fail,$length(got)>30,"the stored .01 reads back over the 30-char DD width (got len="_$length(got)_")")
 do teardown(file,iens)
 quit
 ;
tCaretSilentlyCorruptsSibling(pass,fail) ;@TEST "ADVERSARIAL (F1, severe): a ^-bearing .01 silently OVERWRITES sibling fields sharing the same storage node — cross-field corruption, NO raise"
 ; In #999001 (VSL AUDIT) the .01 is stored at node 0;1 and TIMESTAMP at 0;2 — SAME
 ; node. Internal filing of "A^B^C" into .01 sets node 0 = "A^B^C", so "B" lands in the
 ; TIMESTAMP slot and "C" in USER, with NO DIERR. $$get(.01) truncates to "A"; the
 ; siblings read back the injected ^-pieces. This is the severe form of the F1 hazard:
 ; one field's ^ silently corrupts adjacent fields. Confirmed dual-engine on the
 ; canonical VSL AUDIT build (vehu YDB + foia IRIS). Soft-skips if #999001 is absent.
 new file,iens,raised,ts,$etrap
 do setup(.file)
 if '$data(^DD(999001,0)) do true^STDASSERT(.pass,.fail,1,"VSL AUDIT (#999001) DD not resident here - sibling corruption verified on vehu") quit
 set raised=0,$etrap="set raised=1,$ecode="""" quit"
 set iens=$$set^VSLFS(999001,"+1,",".01","A^B^C")
 set $etrap=""
 do false^STDASSERT(.pass,.fail,raised,"a ^-bearing .01 files into a shared node with NO raise (silent — no DIERR guard)")
 quit:iens=""
 do eq^STDASSERT(.pass,.fail,$$get^VSLFS(999001,iens,".01","MISS"),"A",".01 reads back truncated to its first ^-piece (A)")
 set ts=$$get^VSLFS(999001,iens,"1","","I")
 do eq^STDASSERT(.pass,.fail,ts,"B","the sibling TIMESTAMP field (node 0;2) is silently corrupted to the injected ^-piece (B) — cross-field corruption")
 do teardown(999001,iens)
 quit
 ;
 ; ---------- fixtures ----------
 ;
setup(file) ; FileMan programmer context + the dedicated test file (#999000 ZZVSLFS).
 set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT
 set file=999000
 quit
 ;
teardown(file,iens) ; Remove the throwaway record if it still exists.
 new x
 quit:'$$exists^VSLFS(file,iens)
 set x=$$kill^VSLFS(file,iens)
 quit
