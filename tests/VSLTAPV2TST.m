VSLTAPV2TST	; v-stdlib — cache layout v2 + FU-5/14/17/18 end-to-end (capture -> ring -> drain -> envelope).
	; Phase 6: the rich-record capture path the FU-5 broker wrap drives. Proves the
	; cache-layout-v2 ring (header + "p" chunks + "g" MERGE snapshot), the schema-v1
	; drain (dual-mode: v2 records AND legacy v1 strings from $$append), FU-17's single
	; in-path MERGE for a GLOBAL ARRAY result with all serialize/hash deferred to the
	; drain, FU-18 context (duz/job/client), and the byte-exact §15.2 round-trip via
	; VSLTAPFC. The egress leg uses the CAPTURE sink seam (the batch body is returned in
	; `res`, no real PUT), so it runs on a BARE engine:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPV2TST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPV2TST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tScalarV2DrainRoundTrip(.pass,.fail)
	do tContextInDrainedEnvelope(.pass,.fail)
	do tGlobalMergeIsSingleFaithfulSnapshot(.pass,.fail)
	do tGlobalMergeDrainRoundTrip(.pass,.fail)
	do tMixedV1AndV2BothDrain(.pass,.fail)
	do tCaptureIsCryptoFree(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
setup()	; (private) reset, arm with a consumer, configure the capture sink.
	kill ^VSLTAP,^XTMP("VSLTAP")
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","s3sink")="capture"
	set ^VSLTAP("cfg","s3bucket")="vista-traffic"
	set ^VSLTAP("cfg","s3station")="500"
	set ^VSLTAP("cfg","s3proto")="rpc"
	quit
	;
line1(res)	; (private) the single shipped LDJSON line out of res("body").
	quit $piece($get(res("body")),$char(10),1)
	;
tScalarV2DrainRoundTrip(pass,fail)	;@TEST "a scalar v2 record drains to a schema-v1 envelope; payload byte-exact + hash-anchored"
	new rec,res,n,line,t,pay
	do setup()
	set pay="ORWPT INFO"_$char(13,10)_"500;DPT(0)"_$char(1)_"done"
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWPT INFO",rec("payload")=pay,rec("result_kind")="scalar"
	do capture^VSLRPCTAP(.rec)
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,1,"one record shipped")
	set line=$$line1(.res)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the shipped line is well-formed schema-v1 JSON")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("schema_version")),1,"schema_version=1")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("direction")),"resp","direction carried from the header")
	do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,pay),"payload byte-equals the captured source AND the hash anchor is intact")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"the ring is trimmed after the batch ships")
	quit
	;
tContextInDrainedEnvelope(pass,fail)	;@TEST "FU-18: duz/job/client captured at the wrap survive into the shipped envelope"
	new rec,res,n,line,t
	do setup()
	set rec("dir")="resp",rec("call_id")="500-9-3",rec("rpc")="ORQQPL LIST",rec("payload")="x",rec("result_kind")="scalar"
	set rec("duz")="168",rec("job")=4711,rec("client")="10.1.2.3:51001"
	do capture^VSLRPCTAP(.rec)
	set n=$$drain^VSLS3(.res)
	set line=$$line1(.res)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("duz")),"168","duz survives capture->drain")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("job")),4711,"job ($J) survives")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("client")),"10.1.2.3:51001","client IP:port survives")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("call_id")),"500-9-3","call_id survives")
	quit
	;
src()	; (private) build a multi-node GLOBAL ARRAY result fixture; return its closed root ref.
	new r
	set r=$name(^TMP($job,"VSLTV2"))
	kill @r
	set @r@("a")="alpha bytes"
	set @r@("b",1)="beta-one"_$char(1)_"x"
	set @r@("b",2)="beta-two"_$char(13,10)
	set @r@("c","d","e")="deep"_$char(9)_"value"
	quit r
	;
tGlobalMergeIsSingleFaithfulSnapshot(pass,fail)	;@TEST "FU-17: a GLOBAL ARRAY result is captured by one MERGE — the ring snapshot byte-equals the source subtree"
	new rec,r,seq
	do setup()
	set r=$$src()
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU GLOBAL",rec("gref")=r,rec("result_kind")="global"
	do capture^VSLRPCTAP(.rec)
	set seq=$$head^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",seq,"g","a")),@r@("a"),"snapshot node a byte-equals source")
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",seq,"g","b",1)),@r@("b",1),"snapshot node b,1 (with control byte) byte-equals source")
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",seq,"g","c","d","e")),@r@("c","d","e"),"deep snapshot node byte-equals source")
	do true^STDASSERT(.pass,.fail,$$isV2^VSLTAP(seq),"the global record is a v2 record")
	quit
	;
tGlobalMergeDrainRoundTrip(pass,fail)	;@TEST "FU-17: the drain serializes the snapshot off-path; the global result round-trips byte-exact + hash-anchored"
	new rec,r,seq,expect,res,n,line,t
	do setup()
	set r=$$src()
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU GLOBAL",rec("gref")=r,rec("result_kind")="global"
	do capture^VSLRPCTAP(.rec)
	set seq=$$head^VSLTAP()
	; the drain-side serialization of the snapshot (computed before the drain trims it)
	set expect=$$gSerialize^VSLS3(seq)
	do true^STDASSERT(.pass,.fail,expect'="","the snapshot serializes to a non-empty blob")
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,1,"the global record shipped")
	set line=$$line1(.res)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed schema-v1 line")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("result_kind")),"global","result_kind=global")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload_encoding")),"base64","a global result ships base64 (binary-safe)")
	do eq^STDASSERT(.pass,.fail,$$payloadOf^VSLTAPFC(line),expect,"the shipped payload decodes byte-exact to the serialized snapshot")
	do true^STDASSERT(.pass,.fail,$$verify^VSLTAPFC(line),"the payload_sha256 anchors the serialized bytes (intrinsic integrity)")
	quit
	;
tMixedV1AndV2BothDrain(pass,fail)	;@TEST "dual-mode drain: a legacy v1 string record and a v2 record both ship in one batch"
	new rec,res,n,body,l1,l2
	do setup()
	; a legacy synthetic-demonstrator record via the v1 string append
	do arm^VSLTAP()
	set rec=$$appendDummy()
	; a v2 record via the rich capture
	kill rec set rec("dir")="resp",rec("call_id")="500-1-2",rec("rpc")="X",rec("payload")="v2body",rec("result_kind")="scalar"
	do capture^VSLRPCTAP(.rec)
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,2,"both records shipped in one batch")
	set body=$get(res("body"))
	set l1=$piece(body,$char(10),1),l2=$piece(body,$char(10),2)
	do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(l1,"legacy-v1-rec"),"the legacy v1 string record ships byte-exact")
	do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(l2,"v2body"),"the v2 record ships byte-exact")
	quit
	;
appendDummy()	; (private) append one legacy v1 string record; return its value.
	new x
	set x=$$append^VSLTAP("legacy-v1-rec")
	quit "legacy-v1-rec"
	;
tCaptureIsCryptoFree(pass,fail)	;@TEST "the capture path computes NO payload hash (RPC traffic is plain ASCII; no crypto dependency in the broker hot path) — record captured, NOT disabled, header sha256 + hc node empty/absent"
	new rec,h
	do setup()
	set rec("dir")="resp",rec("call_id")="500-1-9",rec("rpc")="ORWPT INFO",rec("payload")="body",rec("result_kind")="scalar"
	do eq^STDASSERT(.pass,.fail,$$appendRec^VSLTAP(.rec),1,"capture succeeds (no crypto involved)")
	do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","the tap did NOT auto-disable")
	set h=+$get(^XTMP("VSLTAP","head"))
	do eq^STDASSERT(.pass,.fail,$data(^XTMP("VSLTAP","data",h,"hc")),0,"no per-chunk hash node is written in the capture path")
	do eq^STDASSERT(.pass,.fail,$piece($get(^XTMP("VSLTAP","data",h)),"^",18),"","payload_sha256 (piece 18) empty when hashing skipped")
	quit
