#!/bin/sh
export PEM_FILE="/Users/infu/.config/dfx/identity/$(dfx identity whoami)/identity.pem"
#./build.sh
quill sns make-upgrade-canister-proposal 824f1a1df2652fb26c0fe1c03ab5ce69f2561570fb4d042cdc32dcb4604a4f03 --pem-file $PEM_FILE --target-canister-id wxer6-3yaaa-aaaal-qjnua-cai --canister-ids-file sns_canister_ids.json --summary-path proposal_summary.md --mode upgrade --wasm-path build/root.wasm.gz > message.json 
