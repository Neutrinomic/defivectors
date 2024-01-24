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

module {

    let RETRY_EVERY_SEC:Float = 5;

    public class Sender({
        errlog : Vector.Vector<Text>;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
        history : History.History;
    }) {

        private func tick() : async () {
            let now = T.now();
            label sending for ((k, v) in Map.entries(dvectors)) {
                label vtransactions for (tx in v.unconfirmed_transactions.vals()) {
                    
                        let ledger = actor(Principal.toText(v.source.ledger)) : Ledger.Oneway;

                        // Retry every 30 seconds
                        let time_for_try = Float.toInt(Float.ceil((Float.fromInt(Nat32.toNat(now - tx.timestamp)))/RETRY_EVERY_SEC));

                        if (tx.tries >= time_for_try) continue vtransactions;
                        tx.tries += 1;

                        var error = false;
                        try {
                            // Relies on transaction deduplication https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-1/README.md
                            ledger.icrc1_transfer({
                                amount = tx.amount - v.source.ledger_fee;
                                to = tx.to;
                                from_subaccount = tx.from.subaccount;
                                created_at_time = ?Nat64.fromNat((Nat32.toNat(tx.timestamp) * 1000000000));
                                memo = ?tx.memo;
                                fee = null;
                            });
                        } catch (e) { // It may reach oneway transaction limit
                            error := true;
                            Vector.add(errlog, "sender:" # Principal.toText(v.source.ledger) # ":" # Error.message(e));
                        };

                        ignore do ? {
                            let to = Map.get(dvectors, Map.n32hash, tx.to_id)!;

                            history.add([v], #tx_sent {
                                vtx_id = tx.id;
                                retry = tx.tries;
                                error;
                            });
                        };
                };
            };
            ignore Timer.setTimer(#seconds 5, tick);
        };

        public func start_timer() {
        ignore Timer.setTimer(#seconds 2, tick);
        }
    };

};
