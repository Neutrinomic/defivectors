#!/bin/bash
dfx canister --network ic stop icpckbtc
dfx deploy --network ic  --argument 'record { 
    NTN_ledger_id = principal "f54if-eqaaa-aaaaq-aacea-cai"; 
    ICP_ledger_id = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    LEFT_ledger = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    RIGHT_ledger = principal "mxzaz-hqaaa-aaaar-qaada-cai"; 
    DEFI_AGGREGATOR = principal "u45jl-liaaa-aaaam-abppa-cai"; 
    LEFT_aggr_id = 3;
    RIGHT_aggr_id = 1;
}' icpckbtc
dfx canister --network ic start icpckbtc
dfx canister --network ic call icpckbtc init