import T "./types";
import Rechain "mo:rechain";
import Ledger "./services/icrc_ledger";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";

module {

    public type ActionError = {ok:Nat; err:Text};

    public func AccountToGValue(a : Ledger.Account) : Rechain.Value {
       #Array(
        switch (a.subaccount) {
            case (?subaccount) [
                #Blob(Principal.toBlob(a.owner)),
                #Blob(subaccount),
            ];
            case (null) [
                #Blob(Principal.toBlob(a.owner)),
            ];
        }
     )
    };


    public type Xfer = {
       ledger: Principal;
       amount: Nat;
       from: Ledger.Account;
       to: Ledger.Account;
       from_owner: Principal;
       to_owner: Principal;
    };

    public type Action = {
        timestamp: Nat;
        kind: {
            #exchange: [Xfer] // ICRC 47
        }
    };

    public func encodeBlock(a: Action) : [Rechain.ValueMap] {
        [
            ("ts", #Nat(a.timestamp)),
            ("btype",
                #Text(
                    switch (a.kind) {
                        case (#exchange(_)) "47exchange";
                    }
                ),
            ),
            switch(a.kind) {
                case (#exchange(xfers)) ("xfers", #Array(Array.map<Xfer, Rechain.Value>(xfers, func(xfer) = #Map([
                    ("ledger", #Array([#Array([#Blob(Principal.toBlob(xfer.ledger))])])),
                    ("amount", #Nat(xfer.amount)),
                    ("from", AccountToGValue(xfer.from)),
                    ("to", AccountToGValue(xfer.to)),
                    ("from_owner", #Array([#Array([#Blob(Principal.toBlob(xfer.from_owner))])])),
                    ("to_owner", #Array([#Array([#Blob(Principal.toBlob(xfer.to_owner))])]))
                ]))))
            }
        ]
    };

    // public func encodeBlock(a : T.History.Tx) : Rechain.Value {
    //     #Map([
    //         ("ts", #Nat(Nat32.toNat(a.timestamp))),
            // (
            //     "btype",
            //     #Text(
            //         switch (a.kind) {
            //             case (#create_vector(_)) "1dvf.create";
            //             case (#source_in(_)) "1dvf.s_in";
            //             case (#destination_in(_)) "1dvf.d_in";
            //             case (#source_out(_)) "1dvf.s_out";
            //             case (#destination_out(_)) "1dvf.d_out";
            //             case (#swap(_)) "1dfv.swap";
            //             case (#withdraw(_)) "1dfv.withdraw";
            //             case (#tx_sent(_)) "1dfv.sent";
            //         }
            //     ),
            // ),
    //         (
    //             "tx",
    //             #Map(
    //                 switch (a.kind) {
    //                     case (#create_vector(x)) [
    //                         ("vid", #Nat(Nat32.toNat(x.vid))),
    //                         ("owner", #Blob(Principal.toBlob(x.owner))),
    //                         ("s_ledger", #Blob(Principal.toBlob(x.source_ledger))),
    //                         ("d_ledger", #Blob(Principal.toBlob(x.destination_ledger))),
    //                     ];
    //                     case (#source_in(x)) [
    //                         ("vid", #Nat(Nat32.toNat(x.vid))),
    //                         ("amt", #Nat(x.amount)),
    //                         ("fee", #Nat(x.fee)),
    //                     ];
    //                     case (#destination_in(x)) 
    //                         switch(x.vtx_id) {
    //                             case (?vtx_id) [
    //                                 ("vid", #Nat(Nat32.toNat(x.vid))),
    //                                 ("amt", #Nat(x.amount)),
    //                                 ("fee", #Nat(x.fee)),
    //                                 ("vtx", #Nat(Nat64.toNat(vtx_id))),
    //                             ];
    //                             case (null) [
    //                                 ("vid", #Nat(Nat32.toNat(x.vid))),
    //                                 ("amt", #Nat(x.amount)),
    //                                 ("fee", #Nat(x.fee)),
    //                             ];
    //                         };
    //                     case (#source_out(x)) [
    //                         ("vid", #Nat(Nat32.toNat(x.vid))),
    //                         ("amt", #Nat(x.amount)),
    //                         ("fee", #Nat(x.fee)),
    //                     ];
    //                     case (#destination_out(x)) [
    //                         ("vid", #Nat(Nat32.toNat(x.vid))),
    //                         ("amt", #Nat(x.amount)),
    //                         ("fee", #Nat(x.fee)),
    //                     ];
    //                     case (#swap(x)) [
    //                         ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
    //                         ("from", #Nat(Nat32.toNat(x.from))),
    //                         ("to", #Nat(Nat32.toNat(x.to))),
    //                         ("amtOut", #Nat(x.amountOut)),
    //                         ("amtIn", #Nat(x.amountIn)),
    //                         ("fee", #Nat(x.fee))
    //                     ];
    //                     case (#withdraw(x)) [
    //                         ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
    //                         ("from", #Nat(Nat32.toNat(x.from))),
    //                         ("to", AccountToGValue(x.to)),
    //                         ("loc",
    //                             #Text(
    //                                 switch (x.location) {
    //                                     case (#source) "source";
    //                                     case (#destination) "destination";
    //                                 }
    //                             ),
    //                         ),
    //                         ("amt", #Nat(x.amount)),
    //                         ("fee", #Nat(x.fee)),
    //                     ];
    //                     case (#tx_sent(x)) [
    //                         ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
    //                         ("ret", #Nat(x.retry)),
    //                         ("err", #Nat(if (x.error) 1 else 0)),
    //                     ];
    //                 }
    //             ),
    //         ),
    //     ]);
    // };
}