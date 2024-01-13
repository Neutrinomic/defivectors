import Vector "mo:vector";
import Ledger "../services/icrc_ledger";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Map "mo:map/Map";
import T "../types";

module {

    public type Mem = {
        var last_indexed_tx : Nat;
        ledger : Principal;
    };

    public class Indexer(mem : Mem, _dvectors : Map.Map<T.DVectorId, T.DVector>) {

        let log = Vector.new<Text>();
        let ledger = actor (Principal.toText(mem.ledger)) : Ledger.Self;

        private func processtx(transactions : [Ledger.Transaction]) {

            for (t in transactions.vals()) {
                label loopentries for ((k,v) in Map.entries<T.DVectorId, T.DVector>(_dvectors)) {
                    
                    if (v.source.ledger != mem.ledger) continue loopentries;
                    let ?tr = t.transfer else continue loopentries;

                    if (tr.to == v.source.address) {
                        // tokens added to source
                        v.source_balance := v.source_balance + tr.amount;
                    };
                    if (tr.from == v.source.address) {
                        // tokens removed from source
                        v.source_balance := v.source_balance - tr.amount;
                    };
                    if (tr.to == v.destination.address) {
                        // tokens added to destination
                        v.destination_balance := v.destination_balance - tr.amount;

                        // find which vector they came from based on tr.from
                        let ?dv_from = Map.find<T.DVectorId, T.DVector>(_dvectors, func(k, v) : Bool {
                            v.source.address == tr.from and v.source.ledger == mem.ledger
                        }) else continue loopentries; // Didn't come from one of our vectors

                    };
                    if (tr.from == v.destination.address) {
                        // tokens removed from destination
                        v.destination_balance := v.destination_balance - tr.amount;
                    };
                };
                
                // check if tx is from or to one of our endpoint addresses

            };
        };

        private func proc() : async () {
            let rez = await ledger.get_transactions({
                start = mem.last_indexed_tx;
                length = 1000;
            });

            processtx(rez.transactions);

            mem.last_indexed_tx := mem.last_indexed_tx + rez.transactions.size();

            for (atx in rez.archived_transactions.vals()) {
                let txresp = await atx.callback({
                    start = atx.start;
                    length = atx.length;
                });
                processtx(txresp.transactions);

                mem.last_indexed_tx := mem.last_indexed_tx + txresp.transactions.size();
            };
        };

        public func getlog() : async [Text] {
            Vector.toArray(log);
        };

        private func qtimer() : async () {
            try {
                await proc();
            } catch (e) {
                Vector.add(log, Error.message(e));
            };

            ignore Timer.setTimer(#seconds 1, qtimer);
        };

        ignore Timer.setTimer(#seconds 0, qtimer);
    };

};
