#!/bin/sh
`mocv bin 0.10.2`/moc `mops sources` src/main.mo --idl -o build/main.wasm
