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

module {

    public class Sender({
        errlog : Vector.Vector<Text>;
        dvectors : Map.Map<T.DVectorId, T.DVector>;
    }) {

        private func tick() : async () {
            label sending for ((k, v) in Map.entries(dvectors)) {
                for (tx in v.unconfirmed_transactions.vals()) {
                    if (tx.tries == 0) {
                        let ledger = actor(Principal.toText(v.source.ledger)) : Ledger.Self;
                        tx.tries += 1;

                        let rez = await ledger.icrc1_transfer({
                            amount = tx.amount - v.source.ledger_fee;
                            to = tx.to;
                            from_subaccount = tx.from.subaccount;
                            created_at_time = ?Nat64.fromNat((Nat32.toNat(tx.timestamp) * 1000000000));
                            memo = ?tx.memo;
                            fee = null;
                        });

                        Vector.add(errlog, "sender:"# debug_show(rez));
                    }
                };
            };
            ignore Timer.setTimer(#seconds 5, tick);
        };

        public func start_timer() {
        ignore Timer.setTimer(#seconds 2, tick);
        }
    };

};
