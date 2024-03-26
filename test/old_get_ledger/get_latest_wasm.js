import fs from "fs";
import icblast, { hashIdentity, toState, initArg } from "@infu/icblast";

let ic = icblast({})

let snsw = await ic("qaa6y-5yaaa-aaaaa-aaafa-cai");

let upgradesteps = await snsw.list_upgrade_steps({limit:100});

let last_ledger_hash = upgradesteps.steps[upgradesteps.steps.length-1].pretty_version.ledger_wasm_hash;

console.log(last_ledger_hash);

let wasm = await snsw.get_wasm({hash:last_ledger_hash});


// write uint8array to file as binary ./ledger_canister.wasm
fs.writeFileSync("./ledger_canister.wasm", wasm.wasm.wasm, "binary");
