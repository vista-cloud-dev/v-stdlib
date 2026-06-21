VSLHL7TAPTST	; v-stdlib — VSLHL7TAP (HL7 store-tail adapter) test suite.
	; The decoupled, zero-in-line HL7 tap (spec §4, D-3; G-HL7HOOK resolved by a
	; live probe of vehu 2026-06-20). It tails the message stores the HL7 package
	; ALREADY persisted and tees each new verbatim message into the VSLTAP ring:
	;   - legacy #772  -> ^HL(772,IEN,"IN",seq,0)   (package-managed "IN" multiple)
	;   - HLO  #778/#777 -> ^HLB(IEN,*) header + ^HLA(bodyIEN,1,seq,0) body
	; Non-interference is STRUCTURAL (read-only of an existing store). Proves:
	; verbatim reassembly of both stores; forward-only cursor tail; idempotence;
	; consumer-gating (no consumer -> nothing tapped, cursor frozen); cross-ref
	; subscripts (B/C/AF/AI) skipped; purged-body entries shipped as nothing.
	;
	; Bare engine, no VistA (the store globals are SEEDED to the probed layout):
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLHL7TAPTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLHL7TAPTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tReadLegacyReassemblesVerbatim(.pass,.fail)
	do tReadLegacyPurgedBodyIsEmpty(.pass,.fail)
	do tReadHLOReassemblesVerbatim(.pass,.fail)
	do tTailLegacyShipsNewEntries(.pass,.fail)
	do tTailHLOShipsNewEntries(.pass,.fail)
	do tTailBothStoresInOnePass(.pass,.fail)
	do tTailIsIdempotent(.pass,.fail)
	do tTailConsumerGatedFreezesCursor(.pass,.fail)
	do tTailSkipsCrossRefSubscripts(.pass,.fail)
	do tTailSkipsPurgedBodyEntries(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe tap state + the seeded HL7 stores.
	kill ^VSLTAP,^XTMP("VSLTAP")
	kill ^HL(772),^HLB,^HLA
	quit
	;
seedLegacy(ien,dir,msgid,seg)	; (private) seed one #772 entry from a seg() array (1..N segment lines).
	; doc: @param ien    numeric  the entry IEN
	; doc: @param dir    string   direction I|O (^HL(772,IEN,0) piece 4)
	; doc: @param msgid  string   message id (piece 6)
	; doc: @param seg    array    by-ref seg(1..N)=verbatim segment text
	new i,n
	set n=0
	set ^HL(772,ien,0)="3170627.01^^^"_dir_"^^"_msgid_"^^"_ien_"^D"
	for i=1:1 quit:'$data(seg(i))  set n=i,^HL(772,ien,"IN",i,0)=seg(i)
	set ^HL(772,ien,"IN",0)="^^"_n_"^"_n_"^3170627^"
	quit
	;
seedHLO(ien,body,dir,msgid,msh1,msh2,seg)	; (private) seed one #778 message + its #777 body.
	; doc: @param ien    numeric  the #778 (^HLB) IEN
	; doc: @param body   numeric  the #777 (^HLA) body IEN
	; doc: @param msh1   string   MSH components 1-6 (^HLB(IEN,1))
	; doc: @param msh2   string   MSH components 7-end (^HLB(IEN,2))
	; doc: @param seg    array    by-ref seg(1..N)=body segment lines (MSH excluded)
	new i,n
	set n=0
	set ^HLB(ien,0)=msgid_"^"_body_"^^"_dir_"^link"
	set ^HLB(ien,1)=msh1
	set ^HLB(ien,2)=msh2
	for i=1:1 quit:'$data(seg(i))  set n=i,^HLA(body,1,i,0)=seg(i)
	set ^HLA(body,1,0)="^^"_n_"^"_n_"^3170627^"
	quit
	;
tReadLegacyReassemblesVerbatim(pass,fail)	;@TEST "readLegacy joins the #772 'IN' multiple into the verbatim CR-delimited message"
	new seg,want
	do reset()
	set seg(1)="MSH|^~\&|ROR SITE||||||CSU^C09|5002230625-1|T|2.4"
	set seg(2)="PID|1||0^^^^U||PSEUDO^PATIENT"
	set seg(3)="CSR|VA HEPC^1.5.29.1||500^CAMP MASTER^99VA4"
	do seedLegacy(100,"O","5002230625",.seg)
	set want=seg(1)_$char(13)_seg(2)_$char(13)_seg(3)
	do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(100),want,"the three segments rejoin byte-verbatim, CR-delimited")
	quit
	;
tReadLegacyPurgedBodyIsEmpty(pass,fail)	;@TEST "readLegacy of a purged entry (header only, no 'IN' body) returns the empty string"
	do reset()
	set ^HL(772,200,0)="3170717.234501^^^^^5002230648"
	do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(200),"","a purged #772 entry has no message text")
	quit
	;
tReadHLOReassemblesVerbatim(pass,fail)	;@TEST "readHLO rebuilds MSH from #778 nodes 1+2 and prepends it to the #777 body"
	new seg,want
	do reset()
	set seg(1)="EVN|A01|20170627"
	set seg(2)="PID|1||12345||DOE^JOHN"
	do seedHLO(50,900,"O","MSGID123","MSH|^~\&|APP|FAC|","DEST|FAC2|20170627||ADT^A01|MSGID123|P|2.4",.seg)
	set want="MSH|^~\&|APP|FAC|DEST|FAC2|20170627||ADT^A01|MSGID123|P|2.4"_$char(13)_seg(1)_$char(13)_seg(2)
	do eq^STDASSERT(.pass,.fail,$$readHLO^VSLHL7TAP(50),want,"MSH(1+2) + CR + body segments, byte-verbatim")
	quit
	;
tTailLegacyShipsNewEntries(pass,fail)	;@TEST "tail ships every new #772 entry verbatim and advances the cursor to the last IEN"
	new seg,m1,m3
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set seg(1)="MSH|^~\&|A" do seedLegacy(2230625,"O","ID1",.seg)
	set seg(1)="MSH|^~\&|B" do seedLegacy(2230648,"I","ID2",.seg)
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"both new #772 entries were teed")
	do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),2230648,"the #772 cursor advanced to the last IEN")
	set m1=$$read^VSLTAP($$tail^VSLTAP()+1)
	do eq^STDASSERT(.pass,.fail,m1,"MSH|^~\&|A","the first shipped record is the verbatim first message")
	quit
	;
tTailHLOShipsNewEntries(pass,fail)	;@TEST "tail ships new HLO (#778) entries verbatim and advances the #778 cursor"
	new seg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set seg(1)="EVN|A01" do seedHLO(7,400,"O","MID","MSH|^~\&|X|","Y||ADT^A01|MID|P|2.4",.seg)
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the HLO message was teed")
	do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("778"),7,"the #778 cursor advanced")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$head^VSLTAP()),"MSH|^~\&|X|Y||ADT^A01|MID|P|2.4"_$char(13)_"EVN|A01","the HLO record round-trips verbatim")
	quit
	;
tTailBothStoresInOnePass(pass,fail)	;@TEST "one tail pass drains both the legacy and the HLO store"
	new seg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set seg(1)="MSH|leg" do seedLegacy(10,"O","L1",.seg)
	set seg(1)="EVN|hlo" do seedHLO(3,200,"O","H1","MSH|^~\&|","|ADT",.seg)
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"both stores were tailed in one pass")
	quit
	;
tTailIsIdempotent(pass,fail)	;@TEST "a second tail with no new entries ships nothing and leaves the cursor put"
	new seg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set seg(1)="MSH|x" do seedLegacy(10,"O","L1",.seg)
	do tail^VSLHL7TAP()
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the entry was shipped exactly once across two passes")
	do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),10,"the cursor is unchanged by the empty second pass")
	quit
	;
tTailConsumerGatedFreezesCursor(pass,fail)	;@TEST "no consumer -> tail ships nothing AND does not advance the cursor (catch-up on re-arm)"
	new seg
	do reset()
	do arm^VSLTAP()
	set seg(1)="MSH|x" do seedLegacy(10,"O","L1",.seg)
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"no consumer -> zero capture")
	do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),0,"no consumer -> the cursor is frozen so re-arm catches up")
	quit
	;
tTailSkipsCrossRefSubscripts(pass,fail)	;@TEST "tail skips the non-numeric cross-reference subscripts (B/C/AF/AI) under ^HL(772,"
	new seg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set seg(1)="MSH|x" do seedLegacy(10,"O","L1",.seg)
	set ^HL(772,"B","3170627.01",10)=""
	set ^HL(772,"C","5002230625")=10
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"only the numeric entry was shipped; the B/C cross-refs are skipped")
	quit
	;
tTailSkipsPurgedBodyEntries(pass,fail)	;@TEST "tail advances past a purged (body-less) entry without shipping an empty record"
	new seg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^HL(772,9,0)="3170717^^^^^PURGED"
	set seg(1)="MSH|real" do seedLegacy(11,"O","L2",.seg)
	do tail^VSLHL7TAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the purged body ships nothing; only the real message is teed")
	do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),11,"the cursor still advances past the purged entry")
	quit
