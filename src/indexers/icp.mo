import Vector "mo:vector";
import Ledger "../services/icp_ledger";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Map "mo:map/Map";
import T "../types";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";

module {

    public type Mem = {
        var last_indexed_tx : Nat;
    };

    public class Indexer({
        errlog : Vector.Vector<Text>;
        mem : Mem;
        ledger_id : Principal;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
    }) {

        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;

        private func processtx(transactions : [Ledger.CandidBlock]) {

            for (t in transactions.vals()) {
                label loopentries for ((k, v) in Map.entries<T.DVectorId, T.DVector>(dvectors)) {

                    let ? #Transfer(tr) = t.transaction.operation else continue loopentries;
                    let amount = Nat64.toNat(tr.amount.e8s);
                    let source_account = Principal.toLedgerAccount(v.source.address.owner, v.source.address.subaccount);
                    let destination_account = Principal.toLedgerAccount(v.destination.address.owner, v.destination.address.subaccount);

                    if (v.source.ledger == ledger_id) {

                        if (tr.to == source_account) {
                            // tokens added to source
                            v.source_balance += amount;
                        };
                        if (tr.from == source_account) {
                            // tokens removed from source
                            v.source_balance -= amount + v.source.ledger_fee;

                            // look for transaction and remove it
                            v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                                v.unconfirmed_transactions,
                                func(ut) : Bool {
                                    t.transaction.icrc1_memo != ?ut.memo;
                                },
                            );
                        };
                    };

                    if (v.destination.ledger == ledger_id) {

                        if (tr.to == destination_account) {
                            // tokens added to destination
                            v.destination_balance += amount;

                            // find which vector they came from based on tr.from
                            // let ?dv_from = Map.find<T.DVectorId, T.DVector>(
                            //     dvectors,
                            //     func(k, v) : Bool {
                            //         source_account == tr.from and v.source.ledger == ledger_id
                            //     },
                            // ) else continue loopentries; // Didn't come from one of our vectors

                        };
                        if (tr.from == destination_account) {
                            // tokens removed from destination
                            v.destination_balance -= amount + v.destination.ledger_fee;
                        };
                    };
                };

                // check if tx is from or to one of our endpoint addresses

            };
        };

        type TransactionUnordered = {
            start: Nat64;
            transactions: [Ledger.CandidBlock];
        };

        private func proc() : async () {

            // start from the end of last_indexed_tx = 0
            if (mem.last_indexed_tx == 0) {
                let rez = await ledger.query_blocks({
                    start = 0;
                    length = 1;
                });
                mem.last_indexed_tx := Nat64.toNat(rez.chain_length) - 1;
            };

            let rez = await ledger.query_blocks({
                start = Nat64.fromNat(mem.last_indexed_tx);
                length = 1000;
            });

            if (rez.archived_blocks.size() == 0) {
                 // We can just process the transactions
                 processtx(rez.blocks);
                 mem.last_indexed_tx += rez.blocks.size();
            } else {
                // We need to collect transactions from archive and get them in order
                let unordered = Vector.new<TransactionUnordered>();

                for (atx in rez.archived_blocks.vals()) {
                    let #Ok(txresp) = await atx.callback({
                        start = atx.start;
                        length = atx.length;
                    }) else return;

                    Vector.add(unordered, {
                        start = atx.start;
                        transactions = txresp.blocks;
                    });
                };

                let sorted = Array.sort<TransactionUnordered>( Vector.toArray(unordered), func (a, b) {
                    Nat64.compare(a.start, b.start);
                });

                for (u in sorted.vals()) {
                    assert(u.start == Nat64.fromNat(mem.last_indexed_tx));
                    processtx(u.transactions);
                    mem.last_indexed_tx += u.transactions.size();
                };

                if (rez.blocks.size() != 0) { 
                    processtx(rez.blocks);
                    mem.last_indexed_tx += rez.blocks.size();
                }
            }
        };

        private func qtimer() : async () {
            try {
                await proc();
            } catch (e) {
                Vector.add(errlog, "indexers:icp:" # Principal.toText(ledger_id) # ":" # Error.message(e));
            };

            ignore Timer.setTimer(#seconds 2, qtimer);
        };

        public func start_timer() {
            ignore Timer.setTimer(#seconds 2, qtimer);
        }
    };

};
