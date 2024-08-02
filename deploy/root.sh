#!/bin/bash
#dfx canister --network ic stop root
dfx deploy --network ic  --argument 'opt record { 
    NTN_ledger_id = principal "f54if-eqaaa-aaaaq-aacea-cai"; 
    ICP_ledger_id = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    DEFI_AGGREGATOR = principal "u45jl-liaaa-aaaam-abppa-cai"; 
}' root
#dfx canister --network ic start root
