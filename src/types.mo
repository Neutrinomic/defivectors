import Ledger "./services/icrc_ledger";
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
import Vector "mo:vector";
import Nat "mo:base/Nat";

module {

    public type DVectorId = Nat64;
    public type Timestamp = Nat32;

    public type SwapRequest = {
        id : DVectorId;
        amount : Nat;
    };

    public type SwapResult = {
        recievedSource: Nat;
        sentDestination: Nat;
        returnedDestination: Nat;
    };

    public type SourceEndpointInput = {
        ledger : Principal;
    };

    public type DestinationEndpointInput = {
        address : ?Ledger.Account; // specify if external
        ledger : Principal;
    };

    public type Endpoint = {
        address : Ledger.Account;
        ledger_decimals: Nat;
        ledger_fee: Nat; 
        ledger_symbol : Text;
        ledger : Principal;
    };

    public type DynamicRate = {
        max : Float;
        provider: RateProvider;
    };

    public type DVectorRequest = {
        owner : Principal;

        source : SourceEndpointInput;

        destination : DestinationEndpointInput;

        // Rate - serves to calculate the amount taker has to give
        rate: DynamicRate;
    };

    public type DVector = {
        owner : Principal;
        created : Timestamp;
        source : Endpoint;
        var source_balance : Nat;
        destination : Endpoint;
        var destination_balance : Nat;
        rate: DynamicRate;
        settlement: Vector.Vector<DVectorId>;
    };

    public type RateProvider = {
        #xrc : {
            source: Text;
            destination: Text;
        }
    };



    public type DVectorShared = {
        owner : Principal;
        created : Timestamp;
        source : Endpoint;
        source_balance : Nat;
        destination : Endpoint;
        destination_balance : Nat;
        rate: DynamicRate;
        settlement : [DVectorId];
    };

    public module DVector {
        public func toShared(tr: ?DVector) : ?DVectorShared {
            let ?t = tr else return null;
            ?{
                t with
                source_balance = t.source_balance;
                destination_balance = t.destination_balance;
                settlement = Vector.toArray(t.settlement)
            }
        }
    };

    public func now() : Timestamp {
        Nat32.fromNat(Int.abs(Time.now() / 1000000000));
    };

    public func getDVectorSubaccount(txid : DVectorId, who : { #source; #destination }) : Blob {
        let whobit : Nat8 = switch (who) {
            case (#source) 1;
            case (#destination) 2;
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

    public func getFloatRate(amount1: Nat, decimals1: Nat, amount2:Nat, decimals2:Nat) : Float {
        let r0 = floatAmount(amount1, decimals1); 
        let r1 = floatAmount(amount2, decimals2); 
        
        (r1 / r0);
    };

    public func floatAmount(amount: Nat, decimals:Nat) : Float {
        Float.fromInt(amount)/ (10 ** Float.fromInt(decimals)); 
    };

    public func natAmount(amount: Float, decimals:Nat) : Nat {
        Int.abs(Float.toInt(amount * (10 ** Float.fromInt(decimals)))); 
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
