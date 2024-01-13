import Map "mo:map/Map";
import T "./types";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Float "mo:base/Float";

module {

    type K = T.DVectorId;
    type V = T.DVector;

    public func compareVectorRates(v1 : V, v2 : V) : Order.Order {
        if (v1.rate == v2.rate) {
            return #equal;
        } else if (v1.rate > v2.rate) {
            return #greater;
        } else {
            return #less;
        };
    };

    public func settle(dvectors : Map.Map<K, V>, ledger_from : Principal, ledger_to : Principal) {

        let left_side = Map.entries(dvectors)
        |> Iter.filter<(K, V)>(
            _,
            func(k, v) : Bool {
                v.source.ledger == ledger_from and v.source_balance > v.source.ledger_fee * 10 and v.active == true
            },
        )
        |> Iter.sort<(K, V)>(_, func((k, v), (k2, v2)) = compareVectorRates(v, v2)) // we want the highest rates first
        |> Iter.toArray(_);

        let right_side = Map.entries(dvectors)
        |> Iter.filter<(K, V)>(
            _,
            func(k, v) : Bool {
                v.source.ledger == ledger_to and v.source_balance > v.source.ledger_fee * 10 and v.active == true
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
            let right_rate = 1/right.rate;

            // if rates overlap then we have a match
            // the final rate is the average of the two rates
            let final_rate = (left_rate + right_rate) / 2;
            if (final_rate > left_rate or final_rate < right_rate) return; // no overlap we are done

            // use tradable_source_balance to create a transfer between the two vectors
            // AI add from here...
            
            // Determine the maximum amount that can be transferred
            var left_max_transferable = T.floatAmount(left.tradable_source_balance, left.source.ledger_decimals);
            var right_max_transferable = T.floatAmount(right.tradable_source_balance, right.source.ledger_decimals) * final_rate;

            let transfer_amount = Float.min(left_max_transferable, right_max_transferable);

            // Execute transfers
            // Transfer from left to right
            left.tradable_source_balance := left.tradable_source_balance -  T.natAmount(transfer_amount, left.source.ledger_decimals);
            right.destination_balance := right.destination_balance +  T.natAmount(transfer_amount, left.source.ledger_decimals);

            // Transfer from right to left (considering the rate)
            let right_transfer_amount = transfer_amount / final_rate;
            right.tradable_source_balance := right.tradable_source_balance - T.natAmount(right_transfer_amount, left.source.ledger_decimals);
            left.destination_balance := left.destination_balance + T.natAmount(right_transfer_amount, left.source.ledger_decimals);

            // Update the vectors if partial transfer
            if (left.tradable_source_balance == 0) {
                left_index := left_index + 1;
            };
            if (right.tradable_source_balance == 0) {
                right_index := right_index + 1;
            }

        };
    };

};
