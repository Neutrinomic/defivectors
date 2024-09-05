#!/bin/sh
`mocv bin 0.12.1`/moc `mops sources` src/main.mo --idl --public-metadata candid:service --public-metadata candid:args -o build/main.wasm
didc bind "build/main.did" --target js > "build/main.idl.js"
didc bind "build/main.did" --target ts > "build/main.idl.d.ts"
  
`mocv bin 0.12.1`/moc `mops sources` src/root.mo --idl --public-metadata candid:service --public-metadata candid:args -o build/root.wasm
didc bind "build/root.did" --target js > "build/root.idl.js"
didc bind "build/root.did" --target ts > "build/root.idl.d.ts"
gzip -c build/root.wasm > build/root.wasm.gz
