import Ledger "./services/ledger";
import I "mo:itertools/Iter";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Debug "mo:base/Debug";


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
        ledger_decimals: Nat;
        ledger_fee: Nat; 
        ledger_symbol : Text;
    };

    public type TSWaiting = {
        maker_balance: Nat;
        taker_balance: Nat;
        requested_rate: Float;
        provided_rate: Float;
        rate_in_range: Bool;
        rate_match: Bool;
        taker_min_calc_required: Nat;
    };

    public type TSSwapped = {
        maker_amount: Nat;
        maker_distributed: Bool;
        taker_amount: Nat;
        taker_distributed: Bool;
        collateral_sent: Bool;
        final_rate: Float;
    };
    
    public type TSExpired = {
        maker_refunded: Bool;
        taker_refunded: Bool;
        collateral_sent: Bool;
    };

    public type TransactionStatus = {
        #pending;
        #waiting: TSWaiting;
        #swapped : TSSwapped;
        #expired : TSExpired;
       
    };

    public type TransactionRequest = {

        // The entity that has to make the first move
        maker : ParticipantInput;

        // If the deal fails it gets transferred to the maker. If deal succeeds it gets returned to initiator
        initiator_collateral : Nat;

        // Taker seat may be set when initiating the transaction
        taker : ParticipantInput;

        // If the deal isn't complete after this date everything gets returned & collateral lost
        expires : Timestamp;

        // The amount maker wants to give
        maker_amount : Nat;

        // Rate - serves to calculate the amount taker has to give
        rate: {
            max : Float;
            provider: RateProvider;
        }
    };

    public type RateProvider = {
        #xrc : {
            taker: Text;
            maker: Text;
        }
    };

    public type Transaction = TransactionRequest and {
        // The entity that creates the Order. It doesn't have to be the maker - it will require too many proposals when the maker or taker is a DAO
        initiator : Principal;

        created : Timestamp;
        maker : Participant;
        taker : Participant;
        var status : TransactionStatus;
    };

    public type TransactionShared = TransactionRequest and {
        initiator : Principal;

        created : Timestamp;
        maker : Participant;
        taker : Participant;
        status : TransactionStatus;
    };

    public module Transaction {
        public func toShared(tr: ?Transaction) : ?TransactionShared {
            let ?t = tr else return null;
            ?{
                t with
                status = t.status;
            }
        }
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

    public func getPrincipalSubaccount(p : Principal) : Blob {
        let a = Array.init<Nat8>(32, 0);
        let pa = Principal.toBlob(p);
        a[0] := Nat8.fromNat(pa.size());

        var pos = 1;
        for (x in pa.vals()) {
                a[pos] := x;
                pos := pos + 1;
            };

        Blob.fromArray(Array.freeze(a));
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

    // This looses precision but makes thigs easier. It uses only 4 symbols after the decimal point
    public func getFloatRate(amount1: Nat, decimals1: Nat, amount2:Nat, decimals2:Nat) : Float {
        let r0 = Float.fromInt(amount1 / (10 ** (decimals1 - 4))); 
        let r1 = Float.fromInt(amount2 / (10 ** (decimals2 - 4)));
        
        (r1 / r0);
    };


    public func ledgerMeta( ledger_id : Principal ) : async {symbol:Text; decimals:Nat; fee:Nat} {
        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;
        let meta = await ledger.icrc1_metadata();

        let ?#Text(symbol) = findLedgerMetaVal("icrc1:symbol", meta) else Debug.trap("Can't find ledger symbol");
        let ?#Nat(fee) = findLedgerMetaVal("icrc1:fee", meta) else Debug.trap("Can't find ledger fee");
        let ?#Nat(decimals) = findLedgerMetaVal("icrc1:decimals", meta) else Debug.trap("Can't find ledger decimals");

        {symbol; decimals; fee};
    };


    private func findLedgerMetaVal(key : Text, values : [(Text, Ledger.MetadataValue)]) : ?Ledger.MetadataValue {
        let ?f = Array.find<(Text, Ledger.MetadataValue)>(values, func((k : Text, d : Ledger.MetadataValue)) = k == key) else return null;
        ?f.1;
    };
};
