import Vector "mo:vector";
import Ledger "../services/icrc_ledger";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Map "mo:map/Map";
import T "../types";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

module {

    public type Mem = {
        var last_indexed_tx : Nat;
    };

    public class Indexer({errlog: Vector.Vector<Text>; mem : Mem; ledger_id : Principal; dvectors : Map.Map<T.DVectorId, T.DVector>}) {

        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;

        private func processtx(transactions : [Ledger.Transaction]) {

            for (t in transactions.vals()) {
                label loopentries for ((k,v) in Map.entries<T.DVectorId, T.DVector>(dvectors)) {
                    
                    let ?tr = t.transfer else continue loopentries;

                    if (v.source.ledger == ledger_id) {
                        if (tr.to == v.source.address) {
                            // tokens added to source
                            v.source_balance += tr.amount;
                        };
                        if (tr.from == v.source.address) {
                            // tokens removed from source
                            v.source_balance -= tr.amount + v.source.ledger_fee;

                            // look for transaction and remove it
                            v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(v.unconfirmed_transactions, func (ut) : Bool {
                                tr.memo != ?ut.memo
                            });
                        };
                    };

                    if (v.destination.ledger == ledger_id) {
                        if (tr.to == v.destination.address) {
                            // tokens added to destination
                            v.destination_balance += tr.amount;

                            // // find which vector they came from based on tr.from
                            // let ?dv_from = Map.find<T.DVectorId, T.DVector>(dvectors, func(k, v) : Bool {
                            //     v.source.address == tr.from and v.source.ledger == ledger_id
                            // }) else continue loopentries; // Didn't come from one of our vectors

                        };
                        if (tr.from == v.destination.address) {
                            // tokens removed from destination
                            v.destination_balance -= tr.amount + v.destination.ledger_fee;
                        };
                    }
                };
                
                // check if tx is from or to one of our endpoint addresses

            };
        };

        type TransactionUnordered = {
            start: Nat;
            transactions: [Ledger.Transaction];
        };
        private func proc() : async () {

            // start from the end of last_indexed_tx = 0
            if (mem.last_indexed_tx == 0) {
                let rez = await ledger.get_transactions({
                    start = 0;
                    length = 0;
                });
                mem.last_indexed_tx := rez.log_length-1;
            };

            let rez = await ledger.get_transactions({
                    start = mem.last_indexed_tx;
                    length = 1000;
                });

            if (rez.archived_transactions.size() == 0) {
                // We can just process the transactions
                processtx(rez.transactions);
                mem.last_indexed_tx += rez.transactions.size();
            } else {
                // We need to collect transactions from archive and get them in order
                let unordered = Vector.new<TransactionUnordered>();

                for (atx in rez.archived_transactions.vals()) {
                    let txresp = await atx.callback({
                        start = atx.start;
                        length = atx.length;
                    });

                    Vector.add(unordered, {
                        start = atx.start;
                        transactions = txresp.transactions;
                    });
                };

                let sorted = Array.sort<TransactionUnordered>( Vector.toArray(unordered), func (a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    assert(u.start == mem.last_indexed_tx);
                    processtx(u.transactions);
                    mem.last_indexed_tx += u.transactions.size();
                };

                if (rez.transactions.size() != 0) {
                    processtx(rez.transactions);
                    mem.last_indexed_tx += rez.transactions.size();
                }
            }

        };


        private func qtimer() : async () {
            try {
                await proc();
            } catch (e) {
                Vector.add(errlog, "indexers:icrc:" # Principal.toText(ledger_id) # ":" # Error.message(e))
            };

            ignore Timer.setTimer(#seconds 2, qtimer);
        };

        public func start_timer() {
            ignore Timer.setTimer(#seconds 2, qtimer);
        }
    };

};
