import Map "mo:map/Map";
import T "./types";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Ledger "./services/icrc_ledger";
import Principal "mo:base/Principal";
import Vector "mo:vector";
import Rates "./rates";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import History "./history";
import Monitor "./monitor";
import Prim "mo:⛔";
import ErrLog "./errlog";

module {

    let RETRY_EVERY_SEC:Float = 60;
    let MAX_SENT_EACH_CYCLE:Nat = 125;

    public class Sender({
        errlog : ErrLog.ErrLog;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
        history : History.History;
        monitor : Monitor.Monitor;
    }) {

        private func tick<system>() : async () {
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            let now = T.now();
            var sent_count = 0;
            label sending for ((k, v) in Map.entries(dvectors)) {
                label vtransactions for (tx in v.unconfirmed_transactions.vals()) {
                    
                        let ledger = actor(Principal.toText(tx.ledger)) : Ledger.Oneway;

                        let time_for_try = Float.toInt(Float.ceil((Float.fromInt(Nat32.toNat(now - tx.timestamp)))/RETRY_EVERY_SEC));

                        if (tx.tries >= time_for_try) continue vtransactions;
                        
                        var error = false;
                        try {
                            // Relies on transaction deduplication https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-1/README.md
                            ledger.icrc1_transfer({
                                amount = tx.amount - tx.fee;
                                to = tx.to;
                                from_subaccount = tx.from.subaccount;
                                created_at_time = ?Nat64.fromNat((Nat32.toNat(tx.timestamp) * 1000000000));
                                memo = ?tx.memo;
                                fee = null;
                            });
                            tx.tries += 1;
                            sent_count += 1;
                        } catch (e) { // It may reach oneway transaction limit
                            error := true;
                            errlog.add("sender:" # Principal.toText(tx.ledger) # ":" # Error.message(e));
                            break sending;
                        };

                        history.add([v], #tx_sent {
                            vtx_id = tx.id;
                            retry = tx.tries;
                            error;
                        });

                        if (sent_count >= MAX_SENT_EACH_CYCLE) break sending;
                        
                };
            };
            ignore Timer.setTimer<system>(#seconds 2, tick);
            let inst_end = Prim.performanceCounter(1);
            monitor.add(Monitor.SENDER, inst_end - inst_start);

        };

        public func start_timer<system>() {
        ignore Timer.setTimer<system>(#seconds 2, tick);
        }
    };

};
