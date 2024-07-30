#!/bin/sh
`mocv bin 0.11.3`/moc `mops sources` src/main.mo --idl --public-metadata candid:service --public-metadata candid:args -o build/main.wasm
didc bind "build/main.did" --target js > "build/main.idl.js"
didc bind "build/main.did" --target ts > "build/main.idl.d.ts"
  