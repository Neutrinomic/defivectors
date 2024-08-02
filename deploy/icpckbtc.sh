#!/bin/bash
dfx canister --network ic call root add_pair 'record { 
    LEFT_ledger = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    RIGHT_ledger = principal "mxzaz-hqaaa-aaaar-qaada-cai"; 
    LEFT_aggr_id = 3;
    RIGHT_aggr_id = 1;
}' 
