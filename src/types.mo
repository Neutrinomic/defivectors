import Ledger "./services/ledger";
import I "mo:itertools/Iter";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";

module {

    public type TransactionId = Nat64;
    public type Timestamp = Nat32;

    public type ParticipantInput = {
        // Who owns the seat
        owner : Principal;

        // Refund address is deal fails
        refund : Ledger.Account;

        // Destination address if deal succeeds
        destination : Ledger.Account;

        // Ledger & amount of the token this seat provides
        ledger : Principal;

    };

    public type ParticipantStatus = {
        #match;
        #mismatch;
    };

    public type Participant = ParticipantInput and {
        // The address this seat has to send tokens to
        // The owner of the address is this contract
        // The subaccount is derived from the TransactionId
        swap : Ledger.Account;
        var status : ParticipantStatus;
    };

    public type TransactionStatus = {
        #waiting;
        #swapped;
        #refunded;
    };

    public type TransactionRequest = {

        // The entity that has to make the first move
        maker : ParticipantInput;

        // if `taker_collateral` > 0 the taker has put collateral in NTN to reserve their seat.
        // If the deal fails it gets transferred to the maker. If deal succeeds it gets returned to taker
        taker_collateral : Nat;

        // Taker seat may be set when initiating the transaction
        taker : ?ParticipantInput;

        // If the deal isn't complete after this date everything gets returned & collateral lost
        expires : Timestamp;

        // The amount maker wants to give
        maker_amount : Nat;

        // Rate - serves to calculate the amount taker has to give
        rate : {
            quote : Text;
            base : Text;
            min : Float;
            max : Float;
        };
    };

    public type Transaction = TransactionRequest and {
        // The entity that creates the Order. It doesn't have to be the maker - it will require too many proposals when the maker or taker is a DAO
        initiator : Principal;

        created : Timestamp;
        maker : Participant;
        taker : ?Participant;
    };

    public func now() : Timestamp {
        Nat32.fromNat(Int.abs(Time.now() / 1000000000));
    };

    public func getTransactionSubaccount(txid : TransactionId, who : { #taker; #maker; #collateral }) : Blob {
        let whobit : Nat8 = switch (who) {
            case (#maker) 1;
            case (#taker) 2;
            case (#collateral) 3;
        };
        Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[whobit], ENat64(txid)]), 32, 0 : Nat8)));

    };

    private func ENat64(value : Nat64) : [Nat8] {
        return [
            Nat8.fromNat(Nat64.toNat(value >> 56)),
            Nat8.fromNat(Nat64.toNat((value >> 48) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 40) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 32) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 24) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 16) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 8) & 255)),
            Nat8.fromNat(Nat64.toNat(value & 255)),
        ];
    };

};
