vslcfgdemo      ; v-stdlib VSLCFG demo — XPAR-backed SYS config.
        ;
        ; Round-trips a system-level parameter via Kernel Toolkit's Parameter
        ; Tools (XPAR) at the SYS entity ($$get reads, do set writes).
        ;
        ; Needs a LIVE VistA engine — Kernel + the parameter defined in
        ; PARAMETER DEFINITION (#8989.51). It is NOT bare-engine. Reach the
        ; engine through the driver stack, e.g.
        ;   m vista exec --engine ydb 'do ^vslcfgdemo'
        ;
        do main()
        quit
        ;
main()  ; Read a SYS-level parameter, change it, then restore it.
        new key,was,now
        set key="VPNG GREETING"
        set was=$$get^VSLCFG(key,"(unset)")
        write key," was: ",was,!
        do set^VSLCFG(key,"howdy")
        set now=$$get^VSLCFG(key,"(unset)")
        write key," now: ",now,!
        do set^VSLCFG(key,was)                  ; restore the original value
        quit
