VSLCFG	; v-stdlib — VistA configuration adapter over XPAR (Parameter Tools).
	; doc: @exrun live
	; doc: @exsafe transactional
	;
	; Binds the MSL config-read seam ($$get^STDENV) to VistA's XPAR parameter
	; store at the SYS (system) entity — the faithful analog of STDENV's flat
	; key->value config read. The adapter contains ONLY the VistA binding; no
	; parsing or formatting (that stays in STD*, called up; m/v waterline).
	;
	; Public API:
	;   $$get^VSLCFG(key,default)          — read the SYS-level instance, else default
	;   $$getEffective^VSLCFG(key,default) — read the effective value across the
	;                                        parameter's entity precedence (GET^XPAR
	;                                        "ALL"), else default
	;   $$set^VSLCFG(key,value)            — set a value at the SYS entity (loud on failure)
	;   $$delete^VSLCFG(key)               — clear the SYS instance (DEL^XPAR; loud on failure)
	;   $$lastError^VSLCFG()               — last XPAR failure detail, else ""
	;
	; $$get reads ONLY the SYS instance ($$GET^XPAR("SYS",...)) — the faithful flat
	; STDENV analog. $$getEffective resolves the value XPAR would actually use in
	; context (first-found across the parameter's own precedence chain via the "ALL"
	; entity). Use $$getEffective when you want "what value applies here?", $$get
	; when you specifically want the SYS-level setting.
	;
	; *** ERROR CONTRACT — loud on a failed write, never a silent lost set ***
	; EN^XPAR returns its status by reference as a scalar: 0 (or empty) on success,
	; a positive value (a `#^text` code) on failure. (The corpus documents the
	; `.error` parameter only as "by reference" — body header-only — so >0 = failure
	; is the observed contract $$set enforces, not a cited code provenance.) $$set
	; surfaces a positive return — or a hard M fault in EN^XPAR — as a clean ,U-VSL-CFG-SET,
	; $ECODE, with the detail in ^TMP($job,"vslcfg","err") for $$lastError. Reads of
	; an unset parameter are NOT errors ($$get/$$getEffective return the default).
	; The flag-based $ETRAP pattern is used (never zgoto — the M4 VSLLOG gotcha).
	;
	; XPAR is a Supported API (Kernel Toolkit, ICR #2263) — EN^XPAR and $$GET^XPAR
	; alike.
	;
	quit
	;
get(key,default)	; Read parameter `key` at the SYS entity; return `default` when unset.
	; doc: @param key      string  XPAR parameter name (PARAMETER DEFINITION #8989.51)
	; doc: @param default  string  value returned when the parameter is unset (optional; empty when omitted)
	; doc: @returns        string  the SYS-level value, or `default` when unset
	; doc: @example        do eq^STDASSERT(.pass,.fail,$$get^VSLCFG("ZZVSLCFGNOSUCH","fallback"),"fallback","get: unset parameter returns the default")
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	new v
	set v=$$GET^XPAR("SYS",key,1)
	quit $select(v="":$get(default),1:v)
	;
getEffective(key,default)	; Read the effective value across the parameter's entity precedence; else `default`.
	; doc: @param key      string  XPAR parameter name (PARAMETER DEFINITION #8989.51)
	; doc: @param default  string  value returned when the parameter is unset at every level (optional; empty when omitted)
	; doc: @returns        string  the first value found in the parameter's precedence chain, or `default`
	; doc: The "ALL" entity tells XPAR to walk the precedence multiple defined on the
	; doc: parameter (#8989.51) and return the first level that has a value — what the
	; doc: value would actually resolve to in context. Contrast $$get, which reads only SYS.
	; doc: @example        do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG("ZZVSLCFGNOSUCH","fb"),"fb","getEffective: unset parameter returns the default")
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	new v
	set v=$$GET^XPAR("ALL",key,1)
	quit $select(v="":$get(default),1:v)
	;
set(key,value)	; Set parameter `key` to `value` at the SYS entity; raise on a failed write.
	; doc: @param key    string  XPAR parameter name (#8989.51)
	; doc: @param value  string  value to store at the SYS level
	; doc: @returns      void    side-effecting; no return value (loud on failure)
	; doc: @raises  U-VSL-CFG-SET  the XPAR write failed (detail in $$lastError)
	; doc: @illustrative  the loud-on-failure $$set contract (raises U-VSL-CFG-SET) is exercised by tests/VSLCFGTST.m tSetFailureIsLoud; the inline raises-demo duplicated that canonical assertion
	; doc: @icr 2263 @call EN^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#enxpar-add-change-delete-parameters
	new ERR,$etrap,ok
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	do EN^XPAR("SYS",key,1,value,.ERR)
	set $etrap=""
	if 'ok do raiseXpar("SET",key,"EN^XPAR faulted") quit
	if +$get(ERR)>0 do raiseXpar("SET",key,ERR) quit
	quit
	;
delete(key)	; Clear the SYS-level instance of parameter `key`; raise on a failed delete.
	; doc: @param key    string  XPAR parameter name (#8989.51)
	; doc: @returns      void    side-effecting; no return value (loud on failure)
	; doc: @raises  U-VSL-CFG-DEL  the XPAR delete failed (detail in $$lastError)
	; doc: Clears the SYS instance via DEL^XPAR (which files the FileMan "@" delete sentinel).
	; doc: A deleted parameter then reads exactly like a never-set one ($$get returns the
	; doc: default). NOTE: DEL^XPAR is NOT idempotent — deleting a non-existent SYS instance
	; doc: raises U-VSL-CFG-DEL; guard with $$get if you need an idempotent clear.
	; doc: @illustrative  the success path clears a real SYS parameter instance — a live config mutation; exercised on live VistA by tests/VSLCFGTST.m tDeleteClears
	; doc: @icr 2263 @call DEL^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#delxpar-delete-parameter-value
	new ERR,$etrap,ok
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	do DEL^XPAR("SYS",key,1,.ERR)
	set $etrap=""
	if 'ok do raiseXpar("DEL",key,"DEL^XPAR faulted") quit
	if +$get(ERR)>0 do raiseXpar("DEL",key,ERR) quit
	quit
	;
lastError()	; The last VSLCFG error message (the composed XPAR failure detail).
	; doc: @returns      string  ^TMP($job,"vslcfg","err"), or "" if none
	; doc: @illustrative  $$lastError is exercised by the loud-failure assertion in tests/VSLCFGTST.m tSetFailureIsLoud; the inline ^TMP round-trip duplicated that canonical check
	quit $get(^TMP($job,"vslcfg","err"))
	;
	; ---------- internals ----------
	;
raiseXpar(op,key,detail)	; (private) stash the detail, then raise a clean ,U-VSL-CFG-<op>,.
	set ^TMP($job,"vslcfg","err")=op_"("_key_"): XPAR failed ("_detail_")"
	set $ecode=",U-VSL-CFG-"_op_","
	quit
