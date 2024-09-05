import Map "mo:map/Map";
import T "./types";

import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Ledger "./services/icrc_ledger";
import Principal "mo:base/Principal";

import Timer "mo:base/Timer";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import History "./history";
import Monitor "./monitor";
import Prim "mo:⛔";
import ErrLog "./errlog";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Time "mo:base/Time";

module {

    let RETRY_EVERY_SEC:Float = 120;
    let MAX_SENT_EACH_CYCLE:Nat = 125;
    let retryWindow : Nat64 = 22200_000_000_000;


    public class Sender({
        errlog : ErrLog.ErrLog;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
        history : History.History;
        monitor : Monitor.Monitor;
    }) {
        
        private func adjustTXWINDOW(now:Nat64) : Nat64 {
            // If tx is still not sent after the transaction window, we need to
            // set its created_at_time to the current window or it will never be sent no matter how much we retry.
            let window_idx = now / retryWindow;
            return window_idx * retryWindow;
        };

        private func tick<system>() : async () {
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            let now = T.now();
            let nowU64 = Nat64.fromNat(Int.abs(Time.now()));

            var sent_count = 0;
            label sending for ((k, v) in Map.entries(dvectors)) {

                // Previous bug allowed zero amount transactions to slip in, so we have to remove them before attempting to send
                v.unconfirmed_transactions := Array.filter<T.UnconfirmedTransaction>(
                    v.unconfirmed_transactions,
                    func(tr) : Bool {
                        tr.amount > tr.fee //and tr.tries < 1000
                    }
                );

                label vtransactions for (tx in v.unconfirmed_transactions.vals()) {
                    
                        let ledger = actor(Principal.toText(tx.ledger)) : Ledger.Oneway;

                        let time_for_try = Int.abs(Float.toInt(Float.ceil((Float.fromInt(Nat32.toNat(now - tx.timestamp)))/RETRY_EVERY_SEC)));

                        if (tx.tries >= time_for_try) continue vtransactions;

                        var error = false;
                        try {
                            // Relies on transaction deduplication https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-1/README.md
                            ledger.icrc1_transfer({
                                amount = tx.amount - tx.fee;
                                to = tx.to;
                                from_subaccount = tx.from.subaccount;
                                created_at_time = null; //?adjustTXWINDOW(nowU64);
                                memo = ?tx.memo;
                                fee = null;
                            });
                            tx.tries := time_for_try;
                            sent_count += 1;
                        } catch (e) { // It may reach oneway transaction limit
                            error := true;
                            errlog.add("sender:" # Principal.toText(tx.ledger) # ":" # Error.message(e));
                            break sending;
                        };

                        // history.add([v], #tx_sent {
                        //     vtx_id = tx.id;
                        //     retry = tx.tries;
                        //     error;
                        // });

                        if (sent_count >= MAX_SENT_EACH_CYCLE) break sending;
                        
                };
            };
            let inst_end = Prim.performanceCounter(1);
            monitor.add(Monitor.SENDER, inst_end - inst_start);

        };


        public func tick_wrapper<system>() : async () {
            try {
               await tick<system>();
            } catch (e) {
               errlog.add("sender:tick:" # Error.message(e));
            };
            ignore Timer.setTimer<system>(#seconds 2, tick_wrapper);

        };

        public func start_timer<system>() {
            ignore Timer.setTimer<system>(#seconds 2, tick_wrapper);
        };

    };

};
