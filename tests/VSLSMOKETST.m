VSLSMOKETST	; v-stdlib scaffold smoke suite — proves the test-harness wiring.
	; m-lint: disable-file=M-MOD-020
	; Delegates pass/fail counters by-ref to the STDASSERT helpers (staged
	; from m-stdlib via `m test --routines <m-stdlib>/src`). Replaced by real
	; VSL*TST suites as modules land (VSLCFG first, T1.2).
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tHarnessWired(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tHarnessWired(pass,fail)	;@TEST "scaffold harness is wired (STDASSERT reachable)"
	do eq^STDASSERT(.pass,.fail,1+1,2,"arithmetic")
	do true^STDASSERT(.pass,.fail,1,"truthy holds")
	quit
