VSLGOLD	; v-stdlib — golden fixture for tools/test-manifest-golden.py.
	;
	; A tiny synthetic module: the frozen input for the manifest
	; generator's golden-file regression test (P1.7). It lives under
	; tools/fixtures/ — NOT src/ — so the gen-manifest `VSL*.m` glob and
	; the fmt/lint/test source globs never see it, and its line numbers
	; stay stable for the source.file:line assertion.
	;
	quit
	;
greet(who,loud)	; Return a greeting for `who`, optionally shouted.
	; doc: @param who    string  the name to greet
	; doc: @param loud   bool    1 to upper-case the result
	; doc: @returns      string  the rendered greeting
	; doc: @raises       U-VSLGOLD-ARG  `who` is empty
	; doc: @example      write $$greet^VSLGOLD("world",0)  ; "hello, world"
	; doc: @since        v0.1.0
	; doc: @stable       stable
	; doc: @see          $$bye^VSLGOLD
	if $get(who)="" set $ecode=",U-VSLGOLD-ARG," quit ""
	new g
	set g="hello, "_who
	quit $select(loud:$zconvert(g,"U"),1:g)
	;
bye(who)	; Return a farewell; the live-send path is illustrative-only.
	; doc: @param who    string  the name to bid farewell
	; doc: @returns      string  the rendered farewell
	; doc: @raises       U-VSLGOLD-NET  the (illustrative) network send failed
	; doc: @raisesnodemo U-VSLGOLD-NET  needs a live socket peer; not triggerable on a healthy engine
	; doc: @illustrative  sends the farewell over a live socket; exercised by tests, not a safe one-liner
	quit "bye, "_$get(who)
	;
