import Vector "mo:vector";
import Ledger "../services/icrc_ledger";
import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Map "mo:map/Map";
import T "../types";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import History "../history";
import Blob "mo:base/Blob";
import Monitor "../monitor";
import Prim "mo:⛔";
import Option "mo:base/Option";
import ErrLog "../errlog";
import Time "mo:base/Time";

module {

    public type Mem = {
        var last_indexed_tx : Nat;
        source2vector : Map.Map<Ledger.Account, T.DVectorId>;
        destination2vector : Map.Map<Ledger.Account, T.DVectorId>;
        var paused: Bool;
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
        errlog : ErrLog.ErrLog;
        mem : Mem;
        ledger_id : Principal;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
        history : History.History;
        monitor : Monitor.Monitor;
        metric_key: Monitor.MetricKey;
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

                if (not Option.isNull(t.mint)) {
                    let ?mint = t.mint else continue looptx;
                    ignore do ? {
                        let vid = get_source_vector(mint.to)!;
                        let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                        v.source_balance += mint.amount;
                        history.add([v], #source_in({
                            vid = vid;
                            amount = mint.amount;
                            fee = 0;
                        }))
                    }
                };
                
                if (not Option.isNull(t.burn)) {
                    ignore do ? {
                        let burn = t.burn!;
                        let vid = get_source_vector(burn.from)!;
                        let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                        v.source_balance -= burn.amount;

                        // look for a pending transaction and remove it
                        v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                            v.unconfirmed_transactions,
                            func(ut) : Bool {
                                burn.memo != ?ut.memo;
                            },
                        );
                        history.add([v], #source_out({
                            vid = vid;
                            amount = burn.amount;
                            fee = 0;
                        }))
                    }
                };

                let ?tr = t.transfer else continue looptx;

                ignore do ? {
                    let vid = get_source_vector(tr.to)!;
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                    let fee = tr.fee!;

                    v.source_balance += tr.amount;

                    history.add([v], #source_in({
                        vid = vid;
                        amount = tr.amount;
                        fee = fee;
                    }))
                };

                ignore do ? {
                    let vid = get_source_vector(tr.from)!;
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                    let fee = tr.fee!;
                    v.source_balance -= tr.amount + v.source.ledger_fee;

                    // look for a pending transaction and remove it
                    v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                        v.unconfirmed_transactions,
                        func(ut) : Bool {
                            tr.memo != ?ut.memo;
                        },
                    );
                    
                    history.add([v], #source_out({
                        vid = vid;
                        amount = tr.amount;
                        fee = fee;
                    }))
                    
                };

                ignore do ? {
                    let vid = get_destination_vector(tr.to)!;
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                     
                    let fee = tr.fee!;
                    if (v.remote_destination == false) {
                        v.destination_balance += tr.amount;
                        
                        let vtx_id:?Nat64 = do ? { T.DNat64(Blob.toArray(tr.memo!))! };

                        history.add([v], #destination_in({
                            vtx_id;
                            vid = vid;
                            amount = tr.amount;
                            fee = fee;
                        }))
                    }
                };

                ignore do ? {
                    let vid = get_destination_vector(tr.from)!;
                    let v = Map.get<T.DVectorId, T.DVector>(dvectors, Map.n32hash, vid)!;
                    
                    let fee = tr.fee!;

                    if (v.remote_destination == false) {
                        v.destination_balance -= tr.amount + v.destination.ledger_fee;

                        v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                            v.unconfirmed_transactions,
                            func(ut) : Bool {
                                tr.memo != ?ut.memo;
                            },
                        );

                        history.add([v], #destination_out({
                            vid = vid;
                            amount = tr.amount;
                            fee = fee;
                        }))
                    }
                    
                };

            };
        };

        type TransactionUnordered = {
            start : Nat;
            transactions : [Ledger.Transaction];
        };
        
        var lock:Int = 0;
        let MAX_TIME_LOCKED:Int = 60_000_000_000; // 60 seconds

        private func proc() : async () {
            let now = Time.now();
            if (now - lock < MAX_TIME_LOCKED) return;
            lock := now;

            if (mem.paused) return;
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            // start from the end of last_indexed_tx = 0
            if (mem.last_indexed_tx == 0) {
                let rez = await ledger.get_transactions({
                    start = 0;
                    length = 0;
                });
                mem.last_indexed_tx := rez.log_length -1;
            };

            let query_start = mem.last_indexed_tx;

            let rez = await ledger.get_transactions({
                start = mem.last_indexed_tx;
                length = 1000;
            });

            if (query_start != mem.last_indexed_tx) { lock:=0; return; };
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
                    if (u.start != mem.last_indexed_tx) { lock:=0; return; };
                    processtx(u.transactions);
                    mem.last_indexed_tx += u.transactions.size();
                };

                if (rez.transactions.size() != 0) {
                    processtx(rez.transactions);
                    mem.last_indexed_tx += rez.transactions.size();
                };
            };

            let inst_end = Prim.performanceCounter(1); // 1 is preserving with async
            monitor.add(metric_key, inst_end - inst_start);

            lock:=0;
        };

        public func start_timer<system>() {
            ignore Timer.recurringTimer<system>(#seconds 30, proc);
        };
    };

};
