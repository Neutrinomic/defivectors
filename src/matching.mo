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

module {

    type K = T.DVectorId;
    type V = T.DVector;

    public type MatchingMem = {
        var last_tx_id : Nat64;
    };

    public class Matching({
        mem : MatchingMem;
        errlog : Vector.Vector<Text>;
        rates : Rates.Rates;
        dvectors : Map.Map<K, V>;
    }) {

        // Recalcualte rates
        // Find out what's tradable and what not
        public func prepare_vectors() {
            label preparation for ((k, v) in Map.entries(dvectors)) {
                v.amount_available := v.source_balance - T.sumAmountInTransfers(v); // TODO: add time based availability throttle
                let ?rate_source = rates.get_rate(v.source.ledger) else continue preparation;
                let ?rate_destination = rates.get_rate(v.destination.ledger) else continue preparation;
                v.rate := Float.min(v.algorate.max, rate_source / rate_destination * (1 + v.algorate.discount));
                v.active := v.amount_available > v.source.ledger_fee * 10;
            };
        };

        private func tick() : async () {
            try {
                settle(Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"), Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai"));
            } catch (e) {
                Vector.add(errlog, "matching:settle:" # Error.message(e));
            };
            ignore Timer.setTimer(#seconds 5, tick);
        };

        public func settle(ledger_left : Principal, ledger_right : Principal) {

            prepare_vectors();

            let left_side = Map.entries(dvectors)
            |> Iter.filter<(K, V)>(
                _,
                func(k, v) : Bool {
                    v.source.ledger == ledger_left and v.active == true and v.amount_available > 0;
                },
            )
            |> Iter.sort<(K, V)>(_, func((k, v), (k2, v2)) = compareVectorRates(v, v2)) // we want the highest rates first
            |> Iter.toArray(_);

            let right_side = Map.entries(dvectors)
            |> Iter.filter<(K, V)>(
                _,
                func(k, v) : Bool {
                    v.source.ledger == ledger_right and v.active == true and v.amount_available > 0;
                },
            )
            |> Iter.sort<(K, V)>(_, func((k, v), (k2, v2)) = compareVectorRates(v2, v)) // flipped for reversed order. we want lowest rates first
            |> Iter.toArray(_);

            // match orders

            var left_index = 0;
            var right_index = 0;
            let left_side_length = left_side.size();
            let right_side_length = right_side.size();

            while (left_index < left_side_length and right_index < right_side_length) {
                let (left_id, left) = left_side[left_index];
                let (right_id, right) = right_side[right_index];

                let left_rate = left.rate;
                let right_rate = 1 / right.rate;

                // if rates overlap then we have a match
                // the final rate is the average of the two rates
                let final_rate = (left_rate + right_rate) / 2;
                if (final_rate > left_rate or final_rate < right_rate) return; // no overlap we are done

                // use amount_available to create a transfer between the two vectors
                // AI add from here...

                var left_tradable = T.floatAmount(left.amount_available, left.source.ledger_decimals);
                var right_tradable = T.floatAmount(right.amount_available, right.source.ledger_decimals);

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
        };

        private func make_transaction(from_id : T.DVectorId, from : V, to_id : T.DVectorId, to : V, amount : Float) {

            let amountNat : Nat = T.natAmount(amount, from.source.ledger_decimals);

            let tx_id = mem.last_tx_id;
            mem.last_tx_id += 1;

            let tx : T.UnconfirmedTransaction = {
                amount = amountNat;
                timestamp = T.now();
                from_id = from_id;
                to_id = to_id;
                from = from.source.address;
                to = to.destination.address;
                fee = from.source.ledger_fee;
                memo = Blob.fromArray(T.ENat64(tx_id));
                var tries = 0;
            };

            from.amount_available -= amountNat;
            from.unconfirmed_transactions := Array.append(from.unconfirmed_transactions, [tx]);
            // Vector.add(from.unconfirmed_transactions, tx);

        };

        public func start_timer() {
            ignore Timer.setTimer(#seconds 0, tick);
        }
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
