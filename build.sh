#!/bin/sh
`mocv bin 0.10.2`/moc `mops sources` src/main.mo --idl -o build/main.wasm
didc bind "build/main.did" --target js > "build/main.idl.js"
didc bind "build/main.did" --target ts > "build/main.idl.d.ts"
  