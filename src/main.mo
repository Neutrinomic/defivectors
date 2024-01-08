import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Ledger "./services/ledger";
import Map "mo:map/Map";
import T "./types";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import XRC "./services/xrc";
import Cycles "mo:base/ExperimentalCycles";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";

actor class Swap() = this {
  type R<A, B> = Result.Result<A, B>;
  type TransactionId = T.TransactionId;
  type Timestamp = T.Timestamp;
  type ParticipantInput = T.ParticipantInput;
  type Participant = T.Participant;
  type TransactionStatus = T.TransactionStatus;
  type TransactionRequest = T.TransactionRequest;
  type Transaction = T.Transaction;
  type ParticipantStatus = T.ParticipantStatus;

  let nhash = Map.n64hash;
  let ntn_ledger = actor ("f54if-eqaaa-aaaaq-aacea-cai") : Ledger.Self;

  let neutrinite_treasury : Ledger.Account = {
    owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
    subaccount = ?"\61\47\4b\07\1a\86\0b\27\95\75\c9\54\ce\5f\35\98\f4\f8\63\f8\c6\f4\50\86\0c\d3\c3\11\43\16\ef\2d" : ?Blob;
  };

  stable let _transactions = Map.new<TransactionId, Transaction>();
  stable var _nextTransactionId : TransactionId = 0;

  let exchange_rate_canister : XRC.Self = actor ("uf6dk-hyaaa-aaaaq-qaaaq-cai");

  // Transfer NTN from account using icrc2, trap on error
  private func require_ntn_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async () {
    switch (await ntn_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
      case (#Ok(_))();
      case (#Err(e)) Debug.trap(debug_show (e));
    };
  };

  public shared ({ caller }) func create_transaction(req : TransactionRequest) : async TransactionId {

    // Initiator pays 1 NTN fee
    await require_ntn_transfer(caller, 1_0000_0000, neutrinite_treasury);

    let id = _nextTransactionId;
    _nextTransactionId += 1;

    let transaction : Transaction = {
      req with
      initiator = caller;
      maker = {
        req.maker with
        swap = {
          owner = Principal.fromActor(this);
          subaccount = ?T.getTransactionSubaccount(id, #maker);
        };
        var status = #mismatch : ParticipantStatus;
      } : Participant;
      taker = do ? {
        {
          req.taker! with
          swap = {
            owner = Principal.fromActor(this);
            subaccount = ?T.getTransactionSubaccount(id, #taker);
          };
          var status = #mismatch : ParticipantStatus;
        } : Participant;
      };
      created = T.now();
    };

    Map.set(_transactions, nhash, id, transaction);
    id;
  };

  // public query func get_transaction(id : TransactionId) : async ?Transaction {
  //   Map.get(_transactions, nhash, id);
  // };

  private func update_transaction_status(txid : TransactionId) : async () {
    let ?tx = Map.get(_transactions, nhash, txid) else Debug.trap("no such transaction");

    // if maker is mismatching check if matching

    // get XRC rate

    // if taker is mismatching check if matching (if amount > rate*given)

    // if both match mark the swap as done

    // if swap is done and non distributed send tokens to destination addresses

    // if swap has expired, refund participants

    //-----

    // let maker_ledger = actor (Principal.toText(tx.maker.ledger)) : Ledger.Self;

    // let amount = await maker_ledger.icrc1_balance_of(tx.maker.swap);

    // get_tx_status(tx)

  };

  private func get_xrc_rate(quote : Text, base : Text) : async Float {
    Cycles.add(1_000_000_000);

    let #Ok(r) = await exchange_rate_canister.get_exchange_rate({
      timestamp = null;
      quote_asset = { class_ = #Cryptocurrency; symbol = quote };
      base_asset = { class_ = #Cryptocurrency; symbol = base };
    }) else Debug.trap("Failed to get rate from XRC");

    let rate : Float = Float.fromInt(Nat64.toNat(r.rate)) / 10 ** Float.fromInt(Nat32.toNat(r.metadata.decimals));

    rate;
  };

  // private func get_tx_status(tx : Transaction) : TransactionStatus {

  // }

  // public shared ({ caller }) func convert() : async () {
  // let amount = await old_ledger.icrc1_balance_of({
  //   owner = Principal.fromActor(this);
  //   subaccount = ?callerSubaccount(caller);
  // });
  //   assert switch (await old_ledger.icrc1_transfer({ to = { owner = Principal.fromActor(this); subaccount = null }; subaccount = callerSubaccount(caller); from_subaccount = null; amount; memo = null; created_at_time = null; fee = null })) {
  //     case (#Ok(_)) true;
  //     case (#Err(_)) false;
  //   };
  //   ignore await new_ledger.icrc1_transfer({
  //     to = { owner = Principal.fromActor(this); subaccount = null };
  //     from_subaccount = null;
  //     amount;
  //     memo = null;
  //     created_at_time = null;
  //     fee = null;
  //   });
  // };

  // public shared ({ caller }) func refund() : async () {
  //   let amount = await old_ledger.icrc1_balance_of({
  //     owner = Principal.fromActor(this);
  //     subaccount = ?callerSubaccount(caller);
  //   });
  //   ignore await old_ledger.icrc1_transfer({
  //     to = { owner = caller; subaccount = null };
  //     subaccount = ?callerSubaccount(caller);
  //     from_subaccount = null;
  //     amount;
  //     memo = null;
  //     created_at_time = null;
  //     fee = null;
  //   });
  // };

  // private func callerSubaccount(p : Principal) : [Nat8] {
  //   let a = Array.init<Nat8>(32, 0);
  //   let pa = Principal.toBlob(p);
  //   a[0] := Nat8.fromNat(pa.size());

  //   var pos = 1;
  //   for (x in pa.vals()) {
  //     a[pos] := x;
  //     pos := pos + 1;
  //   };

  //   Array.freeze(a);
  // };

};
