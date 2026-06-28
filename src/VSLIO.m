VSLIO	; v-stdlib — VistA TCP transport adapter over the Kernel device handler.
	; doc: @exrun live
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positives: the analyser reads the Kernel device-handler
	; input variables (IPADDRESS/SOCKET/TIMEOUT/IO/POP) and the device USE/READ
	; targets as locals-before-def; they are the documented ^%ZISTCP I/O
	; convention. Same suppression as STDJSON/STDHTTP/STDNET.
	;
	; Binds the MSL socket seam (STDNET, S4) to VistA's Kernel device handler:
	; outbound TCP via CALL^%ZISTCP / CLOSE^%ZISTCP (ICR #2118, Supported). It
	; exposes the CLIENT subset of STDNET's signature (connect/read/write/close)
	; — VistA has NO Supported Kernel listen/accept (server) API (Kernel Device
	; Handler DG; inbound is the listener-process/JOB pattern), so the SERVER side
	; of a connection stays in the portable STDNET seam, never duplicated here.
	; The adapter contains ONLY the VistA binding; framing/buffering stays in
	; STD* and is called up (m/v waterline).
	;
	; Public API (raw bytes; the handle is the opened device, $$connect's return):
	;   $$connect^VSLIO(host,port,timeout)   — CALL^%ZISTCP outbound -> handle or 0
	;                                          (timeout in seconds; default 30)
	;   $$read^VSLIO(id,maxlen,timeout,.buf) — raw read up to maxlen bytes -> count
	;   $$write^VSLIO(id,buf)                — raw write -> 1/0
	;   $$close^VSLIO(id)                    — CLOSE^%ZISTCP -> 1
	;   $$lastError^VSLIO()                  — last error message, else ""
	;
	; *** SECURITY / TLS GAP — same posture as STDNET (loud, never silent) ***
	; This adapter opens RAW PLAINTEXT TCP. TLS (Kernel $$INIT^XUTLS, ICR #7616,
	; using a named config defaulting to the DEFAULT TLS SERVER CONFIG parameter)
	; is NOT wired: it requires engine TLS infrastructure absent on the test
	; engines (a cert + Kernel patch XU*8.0*787 / an IRIS Security.SSLConfigs
	; entry; IRIS-only per the gold corpus). So $$tlsAvailable^VSLIO()=0 and
	; $$connectTls^VSLIO RAISES ,U-VSLIO-NOTLS, (with $$tlsHelp/$$lastError
	; carrying remediation) rather than fall back to plaintext. This is a GATING
	; cleanup before the MSL/VSL stack is complete — see STDNET's TLS gap
	; (m-stdlib docs/tracking/discoveries.md, 2026-06-16) and VSLIO tier-3.
	;
	; The last error message is stashed at ^TMP($job,"vslio","err") for $$lastError.
	; Errors set $ECODE to one of:
	;   ,U-VSLIO-NOTLS,    TLS requested but not wired (see $$tlsHelp)
	;
	quit
	;
	; ---------- outbound TCP client (the VistA binding) ----------
	;
connect(host,port,timeout)	; Open an outbound TCP connection; return the device handle, else 0.
	; doc: @param   host     string   host/IP to connect to (IPADDRESS)
	; doc: @param   port     numeric  remote TCP port (SOCKET)
	; doc: @param   timeout  numeric  open timeout in seconds (default 30)
	; doc: @returns string   the opened device (handle) on POP=0, else 0
	; doc: @icr 2118 @call CALL^%ZISTCP @status Supported @custodian XU @source XU/krn_8_0_dg_device_handler_ug#callzistcp-make-tcpip-connection-remote-system
	; doc: WARNING: PLAINTEXT — no TLS (see $$tlsAvailable / $$connectTls; known gap).
	; doc: @example   do true^STDASSERT(.pass,.fail,$$connect^VSLIO("127.0.0.1",65000,2)=0,"connect to a closed port returns 0 (POP positive)")
	new IO,POP,pio,dev
	set pio=$io
	do CALL^%ZISTCP(host,port,$get(timeout,30))
	if +$get(POP) use pio quit 0
	set dev=IO
	use pio
	quit dev
	;
read(id,maxlen,timeout,buf)	; Raw-read up to maxlen bytes from a handle.
	; doc: @param   id       string   a handle from $$connect (the device)
	; doc: @param   maxlen   numeric  maximum bytes to read
	; doc: @param   timeout  numeric  seconds to wait for data
	; doc: @param   buf      string   by-ref; receives the bytes read
	; doc: @returns numeric  bytes read (0 on timeout/EOF)
	; doc: @illustrative  needs a live connected handle ($$connect + a peer writing bytes); see tests/VSLIOTST.m tLoopbackEcho (STDNET loopback server).
	new x,pio
	set buf="",pio=$io
	use id read x#maxlen:timeout
	use pio
	set buf=x
	quit $length(x)
	;
write(id,buf)	; Raw-write `buf` to a connected handle.
	; doc: @param   id       string   a handle from $$connect (the device)
	; doc: @param   buf      string   bytes to write (raw, no delimiter)
	; doc: @returns bool     1 on success
	; doc: @illustrative  needs a live connected handle from $$connect to USE/WRITE; see tests/VSLIOTST.m tLoopbackEcho.
	new pio
	set pio=$io
	use id write buf
	use pio
	quit 1
	;
close(id)	; Close an outbound connection opened by $$connect.
	; doc: @param   id       string   a handle from $$connect (the device)
	; doc: @returns bool     1 (idempotent)
	; doc: @icr 2118 @call CLOSE^%ZISTCP @status Supported @custodian XU @source XU/krn_8_0_dg_device_handler_ug#closezistcp-close-tcpip-connection-remote-system
	; doc: @illustrative  needs a live handle from $$connect to CLOSE^%ZISTCP; see tests/VSLIOTST.m tLoopbackEcho.
	new IO,pio
	set pio=$io,IO=id
	do CLOSE^%ZISTCP
	use pio
	quit 1
	;
lastError()	; The last VSLIO error message (e.g. the TLS-gap remediation).
	; doc: @returns string  ^TMP($job,"vslio","err"), or "" if none
	; doc: @example   new had,save set had=$data(^TMP($job,"vslio","err")),save=$get(^TMP($job,"vslio","err")),^TMP($job,"vslio","err")="connectTls: x" do contains^STDASSERT(.pass,.fail,$$lastError^VSLIO(),"connectTls","lastError returns the stashed message") if had set ^TMP($job,"vslio","err")=save quit:had  kill ^TMP($job,"vslio","err")
	quit $get(^TMP($job,"vslio","err"))
	;
	; ---------- TLS (known gap — loud, never silent) ----------
	;
tlsAvailable()	; 0 — VSLIO has no wired TLS (engine TLS infra + XU*8.0*787 absent).
	; doc: @returns bool  always 0 today: raw plaintext only (a known, tracked gap)
	; doc: Check before any secure use; $$tlsHelp has remediation.
	; doc: @example   write $$tlsAvailable^VSLIO()  ; 0
	quit 0
	;
tlsHelp()	; Human-readable remediation for the TLS gap (diagnostics/logs).
	; doc: @returns string  multi-line: why there is no TLS + how to remedy
	; doc: @example   do contains^STDASSERT(.pass,.fail,$$tlsHelp^VSLIO(),"NOTLS","tlsHelp carries the remediation message")
	quit $$noTlsMsg()
	;
connectTls(host,port,timeout,config)	; UNIMPLEMENTED — raises, never opens plaintext.
	; doc: @param   host     string   host/IP (ignored — not implemented)
	; doc: @param   port     numeric  TCP port (ignored — not implemented)
	; doc: @param   timeout  numeric  seconds (ignored — not implemented)
	; doc: @param   config   string   named TLS config (ignored — not implemented)
	; doc: @returns string   never returns a handle; always raises
	; doc: @raises  U-VSLIO-NOTLS  TLS not wired (known gap; see $$tlsHelp)
	; doc: @example   do raises^STDASSERT(.pass,.fail,"set x=$$connectTls^VSLIO(""h"",1,1,""cfg"")","U-VSLIO-NOTLS","connectTls raises U-VSLIO-NOTLS")
	do raiseNoTls("connectTls")
	quit 0
	;
	; ---------- internals ----------
	;
noTlsMsg()	; The TLS-gap remediation message (one source for help + lastError).
	new m,nl
	set nl=$char(10)
	set m="VSLIO-NOTLS: VSLIO opens RAW PLAINTEXT TCP — TLS is NOT wired (a known, tracked gap)."
	set m=m_nl_"Do NOT use it for secure transport: a plaintext socket would silently expose credentials/PHI."
	set m=m_nl_"Remedy (GATING — must close before the MSL/VSL stack is complete):"
	set m=m_nl_" 1. Provision engine TLS: a server cert + Kernel patch XU*8.0*787 (DEFAULT TLS SERVER CONFIG)"
	set m=m_nl_"    + an IRIS Security.SSLConfigs entry (IRIS-only per the corpus), or the GT.M $gtmtls path."
	set m=m_nl_" 2. Wire $$connectTls over the Kernel TLS init API (INIT-XUTLS, ICR #7616) with the named config"
	set m=m_nl_"    + the ISTLSSERVERCONF-XUSUDO validator (#7617), then flip $$tlsAvailable to 1."
	set m=m_nl_" 3. Tracked with STDNET's TLS gap (m-stdlib docs/tracking/discoveries.md, 2026-06-16)."
	quit m
	;
raiseNoTls(who)	; Stash remediation, then raise the known-gap error (loud, not silent).
	set ^TMP($job,"vslio","err")=who_": "_$$noTlsMsg()
	set $ecode=",U-VSLIO-NOTLS,"
	quit
