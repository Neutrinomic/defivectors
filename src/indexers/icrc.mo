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
        source2vector : Map.Map<Ledger.Account, T.DVectorId>;
        destination2vector : Map.Map<Ledger.Account, T.DVectorId>;
    };

    private func ahash_hash(account : Ledger.Account) : Nat32 {
        var hash = Map.phash.0 (account.owner);
        switch (account.subaccount) {
            case (?s) {
                let sh = Map.bhash.0 (s);
                hash := hash ^ sh;
            };
            case (_)();
        };
        hash;
    };

    private func ahash_equal(a1 : Ledger.Account, a2 : Ledger.Account) : Bool {
        a1.owner == a2.owner and a1.subaccount == a2.subaccount
    };

    let ahash = (ahash_hash, ahash_equal);

    public class Indexer({
        errlog : Vector.Vector<Text>;
        mem : Mem;
        ledger_id : Principal;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
    }) {

        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;

        public func register_vector(id : T.DVectorId, dv : T.DVector) {
            if (dv.source.ledger == ledger_id) {
                ignore Map.put<Ledger.Account, T.DVectorId>(mem.source2vector, ahash, dv.source.address, id);
            };

            if (dv.destination.ledger == ledger_id) {
                ignore Map.put<Ledger.Account, T.DVectorId>(mem.destination2vector, ahash, dv.destination.address, id);
            };
        };

        private func get_source_vector(account : Ledger.Account) : ?T.DVectorId {
            return Map.get<Ledger.Account, T.DVectorId>(mem.source2vector, ahash, account);
        };

        private func get_destination_vector(account : Ledger.Account) : ?T.DVectorId {
            return Map.get<Ledger.Account, T.DVectorId>(mem.destination2vector, ahash, account);
        };

        private func processtx(transactions : [Ledger.Transaction]) {

            label looptx for (t in transactions.vals()) {

                let ?tr = t.transfer else continue looptx;

                ignore do ? {
                    let vid = get_source_vector(tr.to);
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid!);

                    v!.source_balance += tr.amount;
                };

                ignore do ? {
                    let vid = get_source_vector(tr.from);
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid!);

                    v!.source_balance -= tr.amount + v!.source.ledger_fee;

                    // look for a pending transaction and remove it
                    v!.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                        v!.unconfirmed_transactions,
                        func(ut) : Bool {
                            tr.memo != ?ut.memo;
                        },
                    );
                };

                ignore do ? {
                    let vid = get_destination_vector(tr.to);
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid!);

                    v!.destination_balance += tr.amount;
                };

                ignore do ? {
                    let vid = get_destination_vector(tr.from);
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid!);

                    v!.destination_balance -= tr.amount + v!.destination.ledger_fee;
                };

            };
        };

        type TransactionUnordered = {
            start : Nat;
            transactions : [Ledger.Transaction];
        };
        private func proc() : async () {

            // start from the end of last_indexed_tx = 0
            if (mem.last_indexed_tx == 0) {
                let rez = await ledger.get_transactions({
                    start = 0;
                    length = 0;
                });
                mem.last_indexed_tx := rez.log_length -1;
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

                    Vector.add(
                        unordered,
                        {
                            start = atx.start;
                            transactions = txresp.transactions;
                        },
                    );
                };

                let sorted = Array.sort<TransactionUnordered>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    assert (u.start == mem.last_indexed_tx);
                    processtx(u.transactions);
                    mem.last_indexed_tx += u.transactions.size();
                };

                if (rez.transactions.size() != 0) {
                    processtx(rez.transactions);
                    mem.last_indexed_tx += rez.transactions.size();
                };
            };

        };

        private func qtimer() : async () {
            try {
                await proc();
            } catch (e) {
                Vector.add(errlog, "indexers:icrc:" # Principal.toText(ledger_id) # ":" # Error.message(e));
            };

            ignore Timer.setTimer(#seconds 2, qtimer);
        };

        public func start_timer() {
            ignore Timer.setTimer(#seconds 2, qtimer);
        };
    };

};
