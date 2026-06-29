# v-stdlib — error codes

v-stdlib unversioned; 7 error codes across 6 modules.

Inverted index over the manifest's `@raises` arrays. Every
`,U-VSL...-,` code a v-stdlib label sets via `set $ecode=`
is listed with the labels that raise it. For an `$ETRAP` handler
that needs to disambiguate sources, this is the lookup table.

## `VSLCFG`

- **`U-VSL-CFG-SET`** — raised by: `set`

## `VSLFS`

- **`U-VSL-FS-DIERR`** — raised by: `set`, `list`

## `VSLIO`

- **`U-VSLIO-NOTLS`** — raised by: `connectTls`

## `VSLLOG`

- **`U-VSL-LOG-WRITE`** — raised by: `write`

## `VSLSEC`

- **`U-VSL-SEC-ARG`** — raised by: `hasKey`, `bySecid`

## `VSLTASK`

- **`U-VSL-TASK-ARG`** — raised by: `askStop`, `stat`, `persist`, `pclear`, `schedule`
- **`U-VSL-TASK-QUEUE`** — raised by: `schedule`

