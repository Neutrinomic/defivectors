#!/bin/bash
dfx canister --network ic call root add_pair 'record { 
    LEFT_ledger = principal "ryjl3-tyaaa-aaaaa-aaaba-cai"; 
    RIGHT_ledger = principal "ss2fx-dyaaa-aaaar-qacoq-cai"; 
    LEFT_aggr_id = 3;
    RIGHT_aggr_id = 2;
}' 