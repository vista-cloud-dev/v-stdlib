VSLTAPFCTST	; v-stdlib — VSLTAPFC fidelity comparator test suite.
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positive: `t` is populated by reference by $$parse^STDJSON.
	; Phase 3 / M2, stage 3.2 (spec §7). PROVES byte-equality, it does not assert
	; it: a shipped envelope's payload re-hashes to its own anchor (intrinsic
	; integrity), the decoded payload byte-equals the captured source (RPC tee vs
	; mirror; HL7 vs #772), and a full corpus reconciles against the read-back
	; objects (every record once, in seq, sha256-matched, no unaccounted drop —
	; the §15.2 round-trip core). All egress-INDEPENDENT (the live MinIO read-back
	; is the integration harness); runs on a BARE engine:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPFCTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tVerifyIntrinsicHash(.pass,.fail)
	do tVerifyDetectsTamper(.pass,.fail)
	do tPayloadOfInline(.pass,.fail)
	do tPayloadOfBase64(.pass,.fail)
	do tMatchesSourceByteExact(.pass,.fail)
	do tMatchesRejectsDrift(.pass,.fail)
	do tReconcilePerfect(.pass,.fail)
	do tReconcileDetectsMismatch(.pass,.fail)
	do tReconcileDetectsMissingAndExtra(.pass,.fail)
	do tManifestShape(.pass,.fail)
	do tLastFidelityEmpty(.pass,.fail)
	do tPersistThenLastFidelity(.pass,.fail)
	do tPersistOverwritesPrevious(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
specials()	; (private) a verbatim record spanning the §15.2 edge cases.
	quit "ORWPT ID INFO"_$char(1)_"500;DPT(0)"_$char(13,10)_"a"_$char(9)_"b\c"_""""_"q"_$char(2)
	;
env(rec,seq,opt)	; (private) build one envelope line for `rec` at `seq`.
	new o
	merge o=opt
	set o("ts")="65800,43200"
	quit $$envelope^VSLS3(rec,"rpc","resp","500",seq,.o)
	;
tVerifyIntrinsicHash(pass,fail)	;@TEST "verify: a faithfully shipped envelope re-hashes to its own sha256 anchor"
	new line
	set line=$$env($$specials(),7)
	do true^STDASSERT(.pass,.fail,$$verify^VSLTAPFC(line),"the envelope's payload matches its hash anchor (no drift)")
	quit
	;
tVerifyDetectsTamper(pass,fail)	;@TEST "verify: a tampered payload no longer matches the hash anchor -> 0"
	new line,tampered
	set line=$$env("the original bytes",3)
	; flip one payload byte while leaving the hash anchor intact
	set tampered=$$retamper(line)
	do eq^STDASSERT(.pass,.fail,$$verify^VSLTAPFC(tampered),0,"a payload byte-change is caught by the hash re-check")
	quit
	;
retamper(line)	; (private) replace the inline payload with different bytes, keep the old hash.
	new t,env
	if '$$parse^STDJSON(line,.t) quit ""
	set env="o"
	set env("ts")="s:"_$$valueOf^STDJSON(t("ts"))
	set env("proto")="s:"_$$valueOf^STDJSON(t("proto"))
	set env("dir")="s:"_$$valueOf^STDJSON(t("dir"))
	set env("station")="s:"_$$valueOf^STDJSON(t("station"))
	set env("conn")="s:"_$$valueOf^STDJSON(t("conn"))
	set env("seq")="n:"_$$valueOf^STDJSON(t("seq"))
	set env("len")="n:"_$$valueOf^STDJSON(t("len"))
	set env("hash")="s:"_$$valueOf^STDJSON(t("hash"))
	set env("enc")="s:"_$$valueOf^STDJSON(t("enc"))
	set env("payload")="s:TAMPERED bytes that differ"
	quit $$encode^STDJSON(.env)
	;
tPayloadOfInline(pass,fail)	;@TEST "payloadOf: decodes an inline envelope back to the verbatim bytes"
	new rec,line
	set rec=$$specials()
	set line=$$env(rec,1)
	do eq^STDASSERT(.pass,.fail,$$payloadOf^VSLTAPFC(line),rec,"inline payload decodes byte-exact")
	quit
	;
tPayloadOfBase64(pass,fail)	;@TEST "payloadOf: decodes a base64 envelope back to the verbatim bytes"
	new rec,line,opt
	set rec=$$specials(),opt("base64")=1
	set line=$$env(rec,1,.opt)
	do eq^STDASSERT(.pass,.fail,$$payloadOf^VSLTAPFC(line),rec,"base64 payload decodes byte-exact")
	quit
	;
tMatchesSourceByteExact(pass,fail)	;@TEST "matches: decoded payload byte-equals the captured source AND the hash is intact"
	new rec,line
	set rec=$$specials()
	set line=$$env(rec,5)
	do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,rec),"tee-vs-source byte-equality (RPC mirror / HL7 #772 proof)")
	quit
	;
tMatchesRejectsDrift(pass,fail)	;@TEST "matches: a single-byte difference from the source is rejected"
	new rec,line
	set rec="hello world"
	set line=$$env(rec,5)
	do eq^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,"hello WORLD"),0,"any drift from the source fails byte-equality")
	quit
	;
tReconcilePerfect(pass,fail)	;@TEST "reconcile: corpus vs read-back envelopes — every record once, byte-equal, in seq"
	new corpus,envs,res,i,ok
	for i=1:1:5 set corpus(i)="rec#"_i_$char(1)_"payload"_$char(13,10)_i
	for i=1:1:5 set envs(i)=$$env(corpus(i),i)
	set ok=$$reconcile^VSLTAPFC(.corpus,.envs,.res)
	do true^STDASSERT(.pass,.fail,ok,"a faithful round-trip reconciles fully")
	do eq^STDASSERT(.pass,.fail,res("matched"),5,"all 5 matched")
	do eq^STDASSERT(.pass,.fail,res("mismatch"),0,"no mismatches")
	do eq^STDASSERT(.pass,.fail,res("missing"),0,"no missing")
	do eq^STDASSERT(.pass,.fail,res("extra"),0,"no extras")
	quit
	;
tReconcileDetectsMismatch(pass,fail)	;@TEST "reconcile: a single drifted record is caught (not a silent pass)"
	new corpus,envs,res,i,ok
	for i=1:1:3 set corpus(i)="record-"_i
	for i=1:1:3 set envs(i)=$$env(corpus(i),i)
	; ship a different body under seq 2 (a drifted capture)
	set envs(2)=$$env("record-2-DRIFTED",2)
	set ok=$$reconcile^VSLTAPFC(.corpus,.envs,.res)
	do eq^STDASSERT(.pass,.fail,ok,0,"reconcile fails when any record drifts")
	do eq^STDASSERT(.pass,.fail,res("mismatch"),1,"exactly one mismatch flagged")
	quit
	;
tReconcileDetectsMissingAndExtra(pass,fail)	;@TEST "reconcile: a dropped record (missing) and an unaccounted record (extra) are both caught"
	new corpus,envs,res,i,ok
	for i=1:1:3 set corpus(i)="record-"_i
	; ship only seq 1 and 3 (seq 2 dropped), plus an unexpected seq 9
	set envs(1)=$$env(corpus(1),1)
	set envs(3)=$$env(corpus(3),3)
	set envs(9)=$$env("surprise",9)
	set ok=$$reconcile^VSLTAPFC(.corpus,.envs,.res)
	do eq^STDASSERT(.pass,.fail,ok,0,"reconcile fails on a drop or an extra")
	do eq^STDASSERT(.pass,.fail,res("missing"),1,"the dropped record (seq 2) is flagged missing")
	do eq^STDASSERT(.pass,.fail,res("extra"),1,"the unaccounted record (seq 9) is flagged extra")
	quit
	;
tManifestShape(pass,fail)	;@TEST "manifest: a fidelity run serialises to a JSON manifest (for the _fidelity object)"
	new res,line,t
	set res("matched")=10,res("mismatch")=0,res("missing")=0,res("extra")=0
	set line=$$manifest^VSLTAPFC(.res,"65800,43200")
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"manifest is well-formed JSON")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("matched")),10,"matched count carried")
	do eq^STDASSERT(.pass,.fail,$$type^STDJSON(t("ok")),"true","ok is JSON true when fully faithful")
	quit
	;
	; ---------- the persisted last-fidelity result (the console getter, spec §8.1) ----------
	;
tLastFidelityEmpty(pass,fail)	;@TEST "lastFidelity: returns '' before any run is persisted (console shows 'pending')"
	new res
	kill ^VSLTAP("fc")
	do eq^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC(),"","no persisted run -> empty (the console shows last-run pending)")
	quit
	;
tPersistThenLastFidelity(pass,fail)	;@TEST "persist: stores the manifest line for the console to read back as JSON"
	new res,line,t
	kill ^VSLTAP("fc")
	set res("matched")=8,res("mismatch")=0,res("missing")=0,res("extra")=0
	do persist^VSLTAPFC(.res,"65800,43200")
	set line=$$lastFidelity^VSLTAPFC()
	do true^STDASSERT(.pass,.fail,line'="","persist makes a last-run result readable")
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the persisted result is the well-formed _fidelity manifest")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("matched")),8,"the matched count round-trips through persistence")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("ts")),"65800,43200","the run timestamp is carried")
	do eq^STDASSERT(.pass,.fail,$$type^STDJSON(t("ok")),"true","a clean run persists ok=true")
	quit
	;
tPersistOverwritesPrevious(pass,fail)	;@TEST "persist: a newer run replaces the prior last-fidelity result (single 'last')"
	new res,line,t
	kill ^VSLTAP("fc")
	set res("matched")=5,res("mismatch")=0,res("missing")=0,res("extra")=0
	do persist^VSLTAPFC(.res,"65800,1")
	set res("matched")=3,res("mismatch")=2,res("missing")=0,res("extra")=0
	do persist^VSLTAPFC(.res,"65800,2")
	set line=$$lastFidelity^VSLTAPFC()
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the last result parses")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("ts")),"65800,2","lastFidelity reflects the most recent run")
	do eq^STDASSERT(.pass,.fail,$$type^STDJSON(t("ok")),"false","a run with mismatches persists ok=false")
	quit
