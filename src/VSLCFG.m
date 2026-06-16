VSLCFG	; v-stdlib — VistA configuration adapter over XPAR (Parameter Tools).
	;
	; Binds the MSL config-read seam ($$get^STDENV) to VistA's XPAR parameter
	; store at the SYS (system) entity — the faithful analog of STDENV's flat
	; key->value config read. The adapter contains ONLY the VistA binding; no
	; parsing or formatting (that stays in STD*, called up; m/v waterline).
	;
	; Public extrinsics:
	;   $$get^VSLCFG(key,default)   — read a SYS-level parameter value, else default
	;   $$set^VSLCFG(key,value)     — set a parameter value at the SYS entity
	;
	; XPAR is a Supported API (Kernel Toolkit, ICR #2263).
	;
	quit
	;
get(key,default)	; Read parameter `key` at the SYS entity; return `default` when unset.
	; doc: @param key      string  XPAR parameter name (PARAMETER DEFINITION #8989.51)
	; doc: @param default  string  value returned when the parameter is unset
	; doc: @returns        string  the SYS-level value, or `default` when unset
	; doc: @example        set greeting=$$get^VSLCFG("VPNG GREETING","hello")
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	new v
	set v=$$GET^XPAR("SYS",key,1)
	quit $select(v="":default,1:v)
	;
set(key,value)	; Set parameter `key` to `value` at the SYS entity.
	; doc: @param key    string  XPAR parameter name (#8989.51)
	; doc: @param value  string  value to store at the SYS level
	; doc: @returns      void    side-effecting; no return value
	; doc: @icr 2263 @call EN^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#enxpar-add-change-delete-parameters
	do EN^XPAR("SYS",key,1,value)
	quit
