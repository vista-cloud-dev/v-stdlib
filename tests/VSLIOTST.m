VSLIOTST ; v-stdlib — VSLIO (VistA TCP transport over ^%ZISTCP) test suite.
 ; Exercises the outbound client binding (CALL^%ZISTCP) against a live VistA,
 ; over the driver stack only (m/v waterline):
 ;   m test --engine ydb  --docker vehu \
 ;     --routines src --routines <m-stdlib>/src tests/VSLIOTST.m
 ;   m test --engine iris --docker foia-t12 --namespace VISTA \
 ;     --routines src --routines <m-stdlib>/src tests/VSLIOTST.m
 ; The loopback (tier 1 POP=0 + tier 2 echo) uses a raw STDNET listener for the
 ; SERVER side (VistA has no Supported listen/accept API). STDNET now runs on
 ; BOTH engines, so the loopback runs on both (VSLIO $$write flushes with
 ; WRITE *-3 on IRIS); the $$available^STDNET() guard only soft-skips where the
 ; listener is genuinely absent (e.g. a bare engine). The connect-failure and
 ; TLS-gap tests run on both engines.
 new pass,fail
 do start^STDASSERT(.pass,.fail)
 ;
 do tConnectFailureReportsPop(.pass,.fail)
 do tLoopbackEcho(.pass,.fail)
 do tTlsGapIsLoud(.pass,.fail)
 ;
 do report^STDASSERT(pass,fail)
 quit
 ;
tConnectFailureReportsPop(pass,fail) ;@TEST "CALL^%ZISTCP to a closed port reports failure (handle 0) — the binding is wired, both engines"
 new h
 set h=$$connect^VSLIO("127.0.0.1",65000,2)
 do true^STDASSERT(.pass,.fail,h=0,"connect to a closed port returns 0 (POP positive)")
 quit
 ;
tLoopbackEcho(pass,fail) ;@TEST "VSLIO CALL^%ZISTCP connects (POP=0) and echoes a byte through ^%ZISTCP (loopback)"
 new srv,cli,conn,port,buf,n
 if '$$available^STDNET() do true^STDASSERT(.pass,.fail,1,"STDNET listener unavailable here (bare engine) - loopback skipped") quit
 set srv=$$listen^STDNET(0)
 set port=$$boundport^STDNET(srv)
 set cli=$$connect^VSLIO("127.0.0.1",port,5)
 do true^STDASSERT(.pass,.fail,cli'=0,"CALL^%ZISTCP connected (POP=0)")
 set conn=$$accept^STDNET(srv,5)
 do true^STDASSERT(.pass,.fail,conn>0,"STDNET server accepted the connection")
 do true^STDASSERT(.pass,.fail,$$write^VSLIO(cli,"ping"),"VSLIO wrote outbound")
 set n=$$read^STDNET(conn,99,5,.buf)
 do eq^STDASSERT(.pass,.fail,buf,"ping","server received VSLIO's bytes")
 set n=$$write^STDNET(conn,"pong")
 set n=$$read^VSLIO(cli,99,5,.buf)
 do eq^STDASSERT(.pass,.fail,buf,"pong","VSLIO received the reply")
 set n=$$close^VSLIO(cli)
 do close^STDNET(conn)
 do close^STDNET(srv)
 quit
 ;
tTlsGapIsLoud(pass,fail) ;@TEST "TLS is a loud, documented gap — never a silent plaintext fallback (both engines)"
 do true^STDASSERT(.pass,.fail,'$$tlsAvailable^VSLIO(),"tlsAvailable()=0 (TLS not wired)")
 do contains^STDASSERT(.pass,.fail,$$tlsHelp^VSLIO(),"NOTLS","tlsHelp carries remediation")
 do raises^STDASSERT(.pass,.fail,"set x=$$connectTls^VSLIO(""h"",1,1,""cfg"")",",U-VSLIO-NOTLS,","connectTls raises exactly ,U-VSLIO-NOTLS,")
 do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped connectTls raise (clean unwind)")
 do contains^STDASSERT(.pass,.fail,$$lastError^VSLIO(),"Remedy","lastError carries the remediation steps")
 quit
