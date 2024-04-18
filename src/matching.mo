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
import History "./history";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Monitor "./monitor";
import SWB "mo:swbstable/Stable";
import ErrLog "./errlog";

module {

    type K = T.DVectorId;
    type V = T.DVector;

    public type MatchingMem = {
        var last_tx_id : Nat64;
    };

    public class Matching({
        mem : MatchingMem;
        errlog : ErrLog.ErrLog;
        rates : Rates.Rates;
        dvectors : Map.Map<K, V>;
        history : History.History;
        monitor : Monitor.Monitor;
        ledger_left : Principal;
        ledger_right : Principal;
    }) {

        // Recalcualte rates
        // Find out what's tradable and what not
        public func prepare_vectors() {
            monitor.measure(Monitor.PREPARE_VECTORS, func () {
                let now = T.now();
                label preparation for ((k, v) in Map.entries(dvectors)) {
                    v.source_balance_available := v.source_balance - T.sumAmountInTransfers(v, v.source.ledger);
                    v.destination_balance_available := v.destination_balance - T.sumAmountInTransfers(v, v.destination.ledger);
                    
                    let ?rate_source = rates.get_rate(v.source.ledger) else continue preparation;
                    let ?rate_destination = rates.get_rate(v.destination.ledger) else continue preparation;
                    v.source_rate_usd := rate_source;
                    v.destination_rate_usd := rate_destination;
                    switch (v.algo) {
                        case (#v1(algo)) {
                            let wiggle = Float.sin((Float.fromInt(Nat32.toNat(now - v.created)) / 6.28) / Float.min(1, algo.multiplier_wiggle_seconds)) * algo.multiplier_wiggle;
                            let multiplier = algo.multiplier + wiggle;

                            v.rate := Float.min(algo.max, (rate_destination / rate_source) * multiplier);
                            if (v.source_balance_tradable_last_update + Nat32.min(1, algo.interval_seconds) < now) {
                                v.source_balance_tradable_last_update := now;
                                let tokens_to_add = T.natAmount(algo.interval_release_usd / rate_source, v.source.ledger_decimals);
                                let tokens_max_tradable = T.natAmount(algo.max_tradable_usd / rate_source, v.source.ledger_decimals);
                                v.source_balance_tradable := Nat.min(v.source_balance_available, Nat.min(v.source_balance_tradable + tokens_to_add, tokens_max_tradable));
                            };
                            v.source_balance_tradable := Nat.min(v.source_balance_tradable, v.source_balance_available);
                            apply_active_rules(v);
                        };
                    };

                };
            })
        };

        private func apply_active_rules(v : T.DVector) : () {
            if (v.source_balance_tradable <= v.source_balance_available) {
                v.active := false;
                return;
            };
            
            v.active := v.source_balance_tradable > v.source.ledger_fee * 300; //Rule: One of the ledgers must not have a fee higher than 300 times the other ledger fee
        };

        private func tick() : async () {
            try {
                await settle();
            } catch (e) {
                errlog.add("matching:settle:" # Error.message(e));
            };
            ignore Timer.setTimer(#seconds 2, tick);
        };

        public func settle() : async () {

            prepare_vectors();
            
            monitor.measure(Monitor.SETTLE_VECTORS, func () {

            let left_side = Map.entries(dvectors)
            |> Iter.filter<(K, V)>(
                _,
                func(k, v) : Bool {
                    v.source.ledger == ledger_left and v.active == true and v.source_balance_tradable > 0;
                },
            )
            |> Iter.sort<(K, V)>(_, func((k, v), (k2, v2)) = compareVectorRates(v, v2)) // we want the highest rates first
            |> Iter.toArray(_);

            let right_side = Map.entries(dvectors)
            |> Iter.filter<(K, V)>(
                _,
                func(k, v) : Bool {
                    v.source.ledger == ledger_right and v.active == true and v.source_balance_tradable > 0;
                },
            )
            |> Iter.sort<(K, V)>(_, func((k, v), (k2, v2)) = compareVectorRates(v2, v)) // flipped for reversed order. we want lowest rates first
            |> Iter.toArray(_);

            // match orders

            var left_index = 0;
            var right_index = 0;
            let left_side_length = left_side.size();
            let right_side_length = right_side.size();

            label matching while (left_index < left_side_length and right_index < right_side_length) {
                let (left_id, left) = left_side[left_index];
                let (right_id, right) = right_side[right_index];
                if (not left.active) {
                    left_index += 1;
                    continue matching;
                };
                if (not right.active) {
                    // these may deactivate after few matches when there aren't enough tokens for a trade
                    right_index += 1;
                    continue matching;
                };
                let left_rate = left.rate;
                let right_rate = 1 / right.rate;

                // if rates overlap then we have a match
                // the final rate is the average of the two rates
                let final_rate = (left_rate + right_rate) / 2;
                if (final_rate > left_rate or right_rate > final_rate) return; // no overlap we are done

                // use source_balance_tradable to create a transfer between the two vectors
                // AI add from here...

                var left_tradable = T.floatAmount(left.source_balance_tradable, left.source.ledger_decimals);
                var right_tradable = T.floatAmount(right.source_balance_tradable, right.source.ledger_decimals);

                // Determine the maximum amount that can be transferred
                var left_max_transferable = left_tradable;
                var right_max_transferable = right_tradable * final_rate;

                let left_transfer_amount = Float.min(left_max_transferable, right_max_transferable);

                // Transfer from left to right
                left_tradable -= left_transfer_amount;

                make_transaction(left_id, left, right_id, right, left_transfer_amount);

                // Transfer from right to left (considering the rate)
                let right_transfer_amount = left_transfer_amount / final_rate;
                right_tradable -= right_transfer_amount;

                make_transaction(right_id, right, left_id, left, right_transfer_amount);

                // Update the vectors if partial transfer
                if (left_tradable == 0) {
                    left_index += 1;
                };
                if (right_tradable == 0) {
                    right_index += 1;
                };

            };
            
            });
        };

        public func make_withdraw_transaction(from_id : T.DVectorId, from : V, amountInc : Nat, to : Ledger.Account, location : T.VLocation) : Nat64 {

            let tx_id = mem.last_tx_id;
            mem.last_tx_id += 1;

            let { from_addr; fee; ledger; amount } = switch (location) {
                case (#source) {
                    let amount = Nat.min(amountInc, from.source_balance_available);
                    from.source_balance_available -= amount;
                    from.source_balance_tradable -= Nat.min(from.source_balance_tradable, amount);
                    {
                        from_addr = from.source.address;
                        fee = from.source.ledger_fee;
                        ledger = from.source.ledger;
                        amount;

                    };
                };
                case (#destination) {
                    let amount = Nat.min(amountInc, from.destination_balance_available);
                    from.destination_balance_available -= amount;
                    {
                        from_addr = from.destination.address;
                        fee = from.destination.ledger_fee;
                        ledger = from.destination.ledger;
                        amount;
                    };
                    
                };
            };

            let tx : T.UnconfirmedTransaction = {
                id = tx_id;
                amount = amount;
                timestamp = T.now();
                from_id = from_id;
                to_id = null;
                from = from_addr;
                to = to;
                fee;
                ledger;
                memo = Blob.fromArray(T.ENat64(tx_id));
                var tries = 0;
            };


            from.unconfirmed_transactions := Array.append(from.unconfirmed_transactions, [tx]); // Probably best if Map
            
            history.add([from], #withdraw({ vtx_id = tx_id; from = from_id; location; to; amount; fee }));

            tx_id;
        };

        private func make_transaction(from_id : T.DVectorId, from : V, to_id : T.DVectorId, to : V, amount : Float) {

            let amountNat : Nat = Nat.min(T.natAmount(amount, from.source.ledger_decimals), from.source_balance_tradable);

            let tx_id = mem.last_tx_id;
            mem.last_tx_id += 1;

            let tx : T.UnconfirmedTransaction = {
                id = tx_id;
                amount = amountNat;
                timestamp = T.now();
                from_id = from_id;
                to_id = ?to_id;
                from = from.source.address;
                to = to.destination.address;
                fee = from.source.ledger_fee;
                ledger = from.source.ledger;
                memo = Blob.fromArray(T.ENat64(tx_id));
                var tries = 0;
            };

            from.source_balance_available -= amountNat;
            from.source_balance_tradable -= amountNat;
            from.unconfirmed_transactions := Array.append(from.unconfirmed_transactions, [tx]);
            apply_active_rules(from);

            history.add([from], #swap({ vtx_id = tx_id; from = from_id; to = to_id; amount = amountNat; fee = from.source.ledger_fee; rate = from.rate }));

        };

        public func start_timer() {
            ignore Timer.setTimer(#seconds 0, tick);
        };
    };

    public func compareVectorRates(v1 : V, v2 : V) : Order.Order {
        if (v1.rate == v2.rate) {
            return #equal;
        } else if (v1.rate > v2.rate) {
            return #greater;
        } else {
            return #less;
        };
    };

};
