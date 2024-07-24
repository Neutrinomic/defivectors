#!/bin/bash
dfx canister --network ic stop icpntn
dfx deploy --network ic  --argument 'record {
    NTN_ledger_id = principal "f54if-eqaaa-aaaaq-aacea-cai"; 
    ICP_ledger_id = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    LEFT_ledger = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    RIGHT_ledger = principal "f54if-eqaaa-aaaaq-aacea-cai"; 
    DEFI_AGGREGATOR = principal "u45jl-liaaa-aaaam-abppa-cai"; 
    LEFT_aggr_id = 3;
    RIGHT_aggr_id = 30;
}' icpntn
dfx canister --network ic start icpntn