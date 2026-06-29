VSLSEC ; v-stdlib — VistA identity/authorization adapter (Kernel).
 ;
 ; Binds the VistA *authorization decision* — the part of the security seam
 ; that has NO portable analog and so cannot live below the waterline. Three
 ; bindings, each VistA-only:
 ;   - the security-key check ($$hasKey, over Kernel's ^XUSEC);
 ;   - the ambient principal ($$duz, the NEW PERSON #200 IEN);
 ;   - the principal -> #200 NAME resolution ($$user), which REUSES VSLFS
 ;     (v->v composition; no FileMan DBS re-bind — waterline §9 no-duplication
 ;     applies within `v` too).
 ;
 ; *** NO portable crypto here — STDCRYPTO owns it. *** Portable token crypto
 ; (SHA digests, HMAC, constant-time compare) lives in STDCRYPTO (libcrypto on
 ; YDB / $SYSTEM.Encryption on IRIS, dual-engine proven) and is called up by a
 ; consumer that needs it. VSLSEC binds NO Kernel hash back end: grounded
 ; 2026-06-16, there is no portable Kernel generic-hash entry point —
 ; $$SHAHASH^XUSHSH is absent on the YDB-VistA test engine (pre XU*8.0*655)
 ; and the classic top-level ^XUSHSH returns a constant on both engines. The
 ; architecture (§3.4) is explicit: "Portable token crypto stays in STD*; the
 ; VistA authorization decision lives in VSL." This module is that decision.
 ;
 ; Public API:
 ;   $$hasKey^VSLSEC(key,duz) — 1 iff `duz` holds security key `key`, else 0
 ;   $$duz^VSLSEC()           — the ambient principal (+$GET(DUZ), the #200 IEN)
 ;   $$user^VSLSEC(duz)       — the #200 NAME for `duz` (via VSLFS), else ""
 ;   $$active^VSLSEC(duz)     — 1 iff `duz` can sign on (=$$ACTIVE^XUSER; fail-closed)
 ;   $$lastError^VSLSEC()     — last error detail, else ""
 ;
 ; *** ERROR CONTRACT — loud on a malformed call, never on a normal DENY ***
 ; An authorization DENY is a normal `0` from $$hasKey — NOT an error. A
 ; malformed call (an empty key name) maps to a clean ,U-VSL-SEC-ARG, $ECODE,
 ; with the detail in ^TMP($job,"vslsec","err") for $$lastError. This mirrors
 ; VSLFS's loud-failure posture (a real fault is loud; an absent value is not).
 ;
 ; ICR note: ^XUSEC is the documented Supported *reference* for security-key
 ; membership ("do not reference the SECURITY KEY (#19.1) file ... check the
 ; ^XUSEC global ... this is (and continues to be) a supported reference" —
 ; Kernel DG, Security Keys). It carries no numeric DBIA in the gold corpus, so
 ; the call is tagged with the notional ICR marker (a read, never a write — the
 ; no-direct-global rule forbids set/kill, not the Supported $D reference). See
 ; docs/memory notional-dbia-not-a-blocker + plan §5.4.
 ;
 quit
 ;
 ; ---------- the authorization decision (the VistA binding) ----------
 ;
hasKey(key,duz) ; 1 iff `duz` (default: the ambient DUZ) holds security key `key`.
 ; doc: @param   key      string   security-key name (SECURITY KEY #19.1 .01)
 ; doc: @param   duz      numeric  the user's #200 IEN; defaults to +$GET(DUZ)
 ; doc: @returns          bool     1 iff the user holds the key; 0 (a normal DENY) otherwise
 ; doc: @raises  U-VSL-SEC-ARG  the call is malformed (an empty key name)
 ; doc: @icr notional @call ^XUSEC @status Supported @custodian XU @source XU/krn_8_0_dg_security_keys_ug#key-lookup
 ; doc: @example  do eq^STDASSERT(.pass,.fail,$$hasKey^VSLSEC("ZZ NO SUCH KEY",1),0,"hasKey is 0 (a normal DENY) for an unheld key")
 ; doc: @illustrative  the held-key positive path (an existing ^XUSEC(key,duz) pair) is exercised on live VistA by tests/VSLSECTST.m; the inline ^XUSEC probe duplicated that canonical assertion
 ; doc: @example  do raises^STDASSERT(.pass,.fail,"set x=$$hasKey^VSLSEC("""",1)","U-VSL-SEC-ARG","$$hasKey with an empty key raises U-VSL-SEC-...")
 if $get(key)="" do raiseArg("hasKey","a key name is required") quit ""
 quit ''$data(^XUSEC(key,$$pduz($get(duz))))
 ;
duz() ; The ambient principal — +$GET(DUZ), the caller's NEW PERSON (#200) IEN.
 ; doc: @returns          numeric  the ambient DUZ (0 when no signon context is set)
 ; doc: @example  new DUZ set DUZ=1 do eq^STDASSERT(.pass,.fail,$$duz^VSLSEC(),1,"$$duz returns the ambient DUZ (NEWed, no side effect)")
 quit +$get(DUZ)
 ;
user(duz) ; The #200 NAME for `duz` (default: the ambient DUZ), resolved via VSLFS.
 ; doc: @param   duz      numeric  the user's #200 IEN; defaults to +$GET(DUZ)
 ; doc: @returns          string   the NEW PERSON (#200) .01 NAME, or "" if absent
 ; doc: Reuses $$get^VSLFS (FileMan DBS) — the principal->#200 binding without
 ; doc: re-binding the DBS (v->v composition; waterline §9 no-duplication).
 ; doc: @illustrative  resolves the #200 NAME via $$GET1^DIQ (FileMan DBS) — exercised on live VistA by tests/VSLSECTST.m; faults on a bare engine ($$GET1^DIQ absent), so not a portable one-liner
 quit $$get^VSLFS(200,$$pduz($get(duz))_",",".01","")
 ;
active(duz) ; 1 iff principal `duz` (default: ambient DUZ) is an active user who can sign on.
 ; doc: @param   duz      numeric  the user's #200 IEN; defaults to +$GET(DUZ)
 ; doc: @returns          bool     1 iff the user can currently sign on (active or new); 0 if
 ; doc:    terminated, DISUSER'd, cannot sign on, or no such #200 record (fail-closed)
 ; doc: An authz decision must DENY a terminated/DISUSER'd principal even if a stale ^XUSEC
 ; doc: key xref lingers — so check $$ACTIVE^XUSER, not just $$hasKey. $$ACTIVE^XUSER returns
 ; doc: ""/0/0^DISUSER/0^TERMINATED^date for inactive, 1^NEW/1^ACTIVE^date for active; piece 1
 ; doc: is collapsed with + (the "" no-record case collapses to 0 too). Absent on a bare
 ; doc: engine -> 0 (fail-closed).
 ; doc: @icr 2343 @call $$ACTIVE^XUSER @status Supported @custodian XU @source XU/krn_8_0_dg_user_ug#activexuser-status-indicator
 ; doc: @example  do eq^STDASSERT(.pass,.fail,$$active^VSLSEC(999999999),0,"$$active is 0 for a non-existent #200 IEN")
 ; doc: @illustrative  the active-principal positive path needs a known active #200 user on live VistA — exercised by tests/VSLSECTST.m; $$ACTIVE^XUSER is absent on a bare engine, so not a portable one-liner
 if $text(ACTIVE^XUSER)="" quit 0
 quit +$$ACTIVE^XUSER($$pduz($get(duz)))
 ;
bySecid(secid) ; The #200 IEN for a SecID via EN1^XUPSQRY (RPC XUPS PERSONQUERY), else "".
 ; doc: @param   secid    string   the IAM Security ID (SECID, NEW PERSON #200 field #205.1)
 ; doc: @returns          numeric  the #200 IEN bound to that SecID, or "" if none / not on a VistA engine
 ; doc: @raises  U-VSL-SEC-ARG  the call is malformed (an empty SecID)
 ; doc: @icr 4575 @call EN1^XUPSQRY @status Controlled Subscription @custodian XU @source XU/krn_8_0_dg_common_services_ug#en1xupsqry-query-new-person-file
 ; doc: The SSOi/2FA identity binding: a federated subject (the SecID claim of a
 ; doc: validated token) -> the local #200 IEN, the way Kernel's own XUSAML/
 ; doc: XUESSO2 resolve an STS SAML token. EN1^XUPSQRY queries #200 by SecID
 ; doc: (param 2; null last name in param 3) and stuffs a by-ref result array
 ; doc: (result(1)=1/0 found-flag; result(1,0)=VPID^IEN^name~...). On a bare
 ; doc: engine (EN1^XUPSQRY absent) this returns "" — the caller $text-gates the
 ; doc: live path. No direct ^VA(200 read: the lookup is the Controlled-
 ; doc: Subscription API and the IEN is read from the returned array (waterline).
 ; doc: @example  do raises^STDASSERT(.pass,.fail,"set x=$$bySecid^VSLSEC("""")","U-VSL-SEC-ARG","$$bySecid("""") raises U-VSL-SEC-...")
 ; doc: @illustrative  the live SecID->#200 lookup (EN1^XUPSQRY, absent on a bare engine) is exercised on live VistA by tests/VSLSECTST.m; the inline $text-gated probe duplicated it
 new RESULT
 if $get(secid)="" do raiseArg("bySecid","a SecID is required") quit ""
 if $text(EN1^XUPSQRY)="" quit ""
 do EN1^XUPSQRY(.RESULT,secid,"")
 quit $$parseQry(.RESULT)
 ;
parseQry(result) ; Extract the #200 IEN from an EN1^XUPSQRY result array, or "".
 ; doc: @internal
 ; doc: result(1) is the found-flag (1 found / 0 not found); result(1,0) is the
 ; doc: first record, VPID^IEN^LastName~First~Middle^SSN^DOB^SEX^ — the IEN is
 ; doc: ^-piece 2. Pure (no VistA) so it is unit-tested on a bare engine.
 if +$get(result(1))'=1 quit ""
 quit $piece($get(result(1,0)),"^",2)
 ;
lastError() ; The last VSLSEC error message (the composed malformed-call detail).
 ; doc: @returns          string   ^TMP($job,"vslsec","err"), or "" if none
 ; doc: @illustrative  $$lastError is exercised by the malformed-call assertion in tests/VSLSECTST.m; the inline $etrap round-trip duplicated that canonical check
 quit $get(^TMP($job,"vslsec","err"))
 ;
 ; ---------- internals ----------
 ;
pduz(duz) ; Resolve the effective principal: `duz` if supplied, else the ambient DUZ.
 quit $select($get(duz)'="":duz,1:+$get(DUZ))
 ;
raiseArg(who,msg) ; Stash the detail, then raise the clean ,U-VSL-SEC-ARG,.
 set ^TMP($job,"vslsec","err")=who_": "_msg
 set $ecode=",U-VSL-SEC-ARG,"
 quit
