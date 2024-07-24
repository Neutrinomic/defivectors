#!/bin/bash
dfx canister --network ic stop icpckusdc
dfx deploy --network ic  --argument 'record {
    NTN_ledger_id = principal "f54if-eqaaa-aaaaq-aacea-cai"; 
    ICP_ledger_id = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    LEFT_ledger = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    RIGHT_ledger = principal "xevnm-gaaaa-aaaar-qafnq-cai"; 
    DEFI_AGGREGATOR = principal "u45jl-liaaa-aaaam-abppa-cai"; 
    LEFT_aggr_id = 3;
    RIGHT_aggr_id = 0;
}' icpckusdc
dfx canister --network ic start icpckusdc