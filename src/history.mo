import T "./types";
import Vector "mo:vector";
import SWB "mo:swbstable/Stable";
import Rechain "mo:rechain";
import Ledger "./services/icrc_ledger";
import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";

module {

    public class History({
        mem : SWB.SlidingWindowBuffer<T.History.Tx>;
    }) {

        public func add(vectors : [T.DVector], kind : T.History.TxKind) {
            let tx : T.History.Tx = {
                timestamp = T.now();
                kind;
            };

            // Add to global history
            let tx_id = mem.add(tx);
            if (mem.len() > 200000) {
                // Max 200,000 total history
                mem.delete(1); // Delete 1 element from the beginning
            };

            // Add to temporary local vector history
            for (v in vectors.vals()) {
                let history_cls = SWB.SlidingWindowBuffer<T.History.TxId>(v.history);
                ignore history_cls.add(tx_id);
                if (history_cls.len() > 300) {
                    // MAX 300 vector local history
                    history_cls.delete(1); // Delete 1 element from the beginning
                };
            };

            // Add to ICRC3 Rechain back log

        };

    };

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

    public func encodeBlock(a : T.History.Tx) : Rechain.Value {
        #Map([
            ("ts", #Nat(Nat32.toNat(a.timestamp))),
            (
                "btype",
                #Text(
                    switch (a.kind) {
                        case (#create_vector(_)) "1dvf.create";
                        case (#source_in(_)) "1dvf.s_in";
                        case (#destination_in(_)) "1dvf.d_in";
                        case (#source_out(_)) "1dvf.s_out";
                        case (#destination_out(_)) "1dvf.d_out";
                        case (#swap(_)) "1dfv.swap";
                        case (#withdraw(_)) "1dfv.withdraw";
                        case (#tx_sent(_)) "1dfv.sent";
                    }
                ),
            ),
            (
                "tx",
                #Map(
                    switch (a.kind) {
                        case (#create_vector(x)) [
                            ("vid", #Nat(Nat32.toNat(x.vid))),
                            ("owner", #Blob(Principal.toBlob(x.owner))),
                            ("s_ledger", #Blob(Principal.toBlob(x.source_ledger))),
                            ("d_ledger", #Blob(Principal.toBlob(x.destination_ledger))),
                        ];
                        case (#source_in(x)) [
                            ("vid", #Nat(Nat32.toNat(x.vid))),
                            ("amt", #Nat(x.amount)),
                            ("fee", #Nat(x.fee)),
                        ];
                        case (#destination_in(x)) 
                            switch(x.vtx_id) {
                                case (?vtx_id) [
                                    ("vid", #Nat(Nat32.toNat(x.vid))),
                                    ("amt", #Nat(x.amount)),
                                    ("fee", #Nat(x.fee)),
                                    ("vtx", #Nat(Nat64.toNat(vtx_id))),
                                ];
                                case (null) [
                                    ("vid", #Nat(Nat32.toNat(x.vid))),
                                    ("amt", #Nat(x.amount)),
                                    ("fee", #Nat(x.fee)),
                                ];
                            };
                        case (#source_out(x)) [
                            ("vid", #Nat(Nat32.toNat(x.vid))),
                            ("amt", #Nat(x.amount)),
                            ("fee", #Nat(x.fee)),
                        ];
                        case (#destination_out(x)) [
                            ("vid", #Nat(Nat32.toNat(x.vid))),
                            ("amt", #Nat(x.amount)),
                            ("fee", #Nat(x.fee)),
                        ];
                        case (#swap(x)) [
                            ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
                            ("from", #Nat(Nat32.toNat(x.from))),
                            ("to", #Nat(Nat32.toNat(x.to))),
                            ("amtOut", #Nat(x.amountOut)),
                            ("amtIn", #Nat(x.amountIn)),
                            ("fee", #Nat(x.fee))
                        ];
                        case (#withdraw(x)) [
                            ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
                            ("from", #Nat(Nat32.toNat(x.from))),
                            ("to", AccountToGValue(x.to)),
                            ("loc",
                                #Text(
                                    switch (x.location) {
                                        case (#source) "source";
                                        case (#destination) "destination";
                                    }
                                ),
                            ),
                            ("amt", #Nat(x.amount)),
                            ("fee", #Nat(x.fee)),
                        ];
                        case (#tx_sent(x)) [
                            ("vtx", #Nat(Nat64.toNat(x.vtx_id))),
                            ("ret", #Nat(x.retry)),
                            ("err", #Nat(if (x.error) 1 else 0)),
                        ];
                    }
                ),
            ),
        ]);
    };
};
