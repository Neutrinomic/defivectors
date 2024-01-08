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
import Int "mo:base/Int";

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
  type TransactionShared = T.TransactionShared;

  let nhash = Map.n64hash;
  let ntn_ledger = actor ("f54if-eqaaa-aaaaq-aacea-cai") : Ledger.Self;

  // let neutrinite_treasury : Ledger.Account = {
  //   owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
  //   subaccount = ?"\61\47\4b\07\1a\86\0b\27\95\75\c9\54\ce\5f\35\98\f4\f8\63\f8\c6\f4\50\86\0c\d3\c3\11\43\16\ef\2d" : ?Blob;
  // };

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

  public shared ({ caller }) func create_transaction(req : TransactionRequest) : async R<TransactionId, Text> {

    // Initiator provides collateral (Min 1 NTN)
    if (req.initiator_collateral < 1_0000_0000) return #err("Collateral must be at least 1 NTN");

    // await require_ntn_transfer(
    //   caller,
    //   req.initiator_collateral,
    //   {
    //     owner = Principal.fromActor(this);
    //     subaccount = ?T.getPrincipalSubaccount(caller);
    //   },
    // );

    let id = _nextTransactionId;
    _nextTransactionId += 1;


    let maker_ledger_meta = await T.ledgerMeta(req.maker.ledger);
    let taker_ledger_meta = await T.ledgerMeta(req.taker.ledger);

    let transaction : Transaction = {
      req with
      initiator = caller;
      maker = {
        req.maker with
        swap = {
          owner = Principal.fromActor(this);
          subaccount = ?T.getTransactionSubaccount(id, #maker);
        };
        ledger_decimals = maker_ledger_meta.decimals;
        ledger_fee = maker_ledger_meta.fee;
        ledger_symbol = maker_ledger_meta.symbol;
      } : Participant;
      taker = {
        req.taker with
        swap = {
          owner = Principal.fromActor(this);
          subaccount = ?T.getTransactionSubaccount(id, #taker);
        };
        ledger_decimals = taker_ledger_meta.decimals;
        ledger_fee = taker_ledger_meta.fee;
        ledger_symbol = taker_ledger_meta.symbol;
      } : Participant;

      created = T.now();
      var status = #pending : T.TransactionStatus;
    };

    Map.set(_transactions, nhash, id, transaction);
    #ok id;
  };

  public query func get_transaction(id : TransactionId) : async ?TransactionShared {
    T.Transaction.toShared(Map.get(_transactions, nhash, id));
  };

  public shared func update_transaction(id : TransactionId) : async () {
    await update_transaction_status(id);
  };

  private func update_transaction_status(txid : TransactionId) : async () {
    let ?tx = Map.get(_transactions, nhash, txid) else Debug.trap("no such transaction");

    let maker_ledger = actor (Principal.toText(tx.maker.ledger)) : Ledger.Self;
    let taker_ledger = actor (Principal.toText(tx.taker.ledger)) : Ledger.Self;

    switch (tx.status) {
      case (#pending or #waiting(_)) {
        let maker_balance = await maker_ledger.icrc1_balance_of(tx.maker.swap);

        let taker_balance = await maker_ledger.icrc1_balance_of(tx.taker.swap);

        // requested_rate from XRC
        let requested_rate = switch(tx.rate.provider) {
          case (#xrc(x)) {
            await get_xrc_rate(x.maker, x.taker);
          };
          //...
        };

        // calculate rate from balances
        let provided_rate = T.getFloatRate(maker_balance, tx.maker.ledger_decimals, taker_balance, tx.taker.ledger_decimals);

        // if maker is mismatching check if matching
        let rate_match = provided_rate <= requested_rate;
        let rate_in_range = requested_rate < tx.rate.max;
        let taker_min_calc_required = Int.abs(Float.toInt((Float.fromInt(maker_balance) * Float.min(requested_rate, tx.rate.max))*Float.fromInt(10**tx.taker.ledger_decimals)));
        let taker_amount_match = taker_min_calc_required <= taker_balance;

        if (T.now() > tx.expires) {
          tx.status := #expired {
            maker_refunded = false;
            taker_refunded = false;
            collateral_sent = false;
          };
        } else {
          if (rate_match and rate_in_range and taker_amount_match) {
            tx.status := #swapped {
              maker_amount = maker_balance;
              taker_amount = taker_balance;
              maker_distributed = false;
              taker_distributed = false;
              final_rate = provided_rate;
              collateral_sent = false;
            };
          } else {
            tx.status := #waiting {
              maker_balance;
              taker_balance;
              requested_rate;
              provided_rate;
              rate_match;
              rate_in_range;
              taker_min_calc_required;
            };
          };
        };

      };
      case (#swapped(sw)) {
    

      };
      case (#expired(re)) {

      };
    };

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
