VSLCFG	; v-stdlib — VistA configuration adapter over XPAR (Parameter Tools).
	;
	; Binds the MSL config-read seam ($$get^STDENV) to VistA's XPAR parameter
	; precedence hierarchy (Kernel Toolkit). The adapter exposes the same
	; config-read shape and contains ONLY the VistA binding — no parsing or
	; formatting (that stays in STD*, called up; m/v waterline).
	;
	; Public extrinsics:
	;   $$get^VSLCFG(key,default)   — read a parameter value via XPAR precedence
	;   $$set^VSLCFG(key,value)     — set a parameter value at the SYS entity
	;
	quit
	;
get(key,default)	; Read parameter `key` via the XPAR precedence hierarchy; else default.
	; doc: @param key      string  XPAR parameter name (PARAMETER DEFINITION #8989.51)
	; doc: @param default  string  value returned when the parameter is unset
	; doc: @returns        string  the parameter value, or `default` when unset
	; doc: @example        set greeting=$$get^VSLCFG("VPNG GREETING","hello")
	quit default
	;
set(key,value)	; Set parameter `key` to `value` at the SYS entity.
	; doc: @param key    string  XPAR parameter name (#8989.51)
	; doc: @param value  string  value to store at the SYS level
	; doc: @returns      void    side-effecting; no return value
	quit
