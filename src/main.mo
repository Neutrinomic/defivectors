import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Ledger "./services/icrc_ledger";
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
import Option "mo:base/Option";
import Vector "mo:vector";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";

actor class Swap() = this {
  type R<A, B> = Result.Result<A, B>;
  type DVectorId = T.DVectorId;
  type Timestamp = T.Timestamp;
  type SourceEndpointInput = T.SourceEndpointInput;
  type DestinationEndpointInput = T.DestinationEndpointInput;
  type Endpoint = T.Endpoint;
  type DVectorRequest = T.DVectorRequest;
  type DVector = T.DVector;
  type DVectorShared = T.DVectorShared;
  type SwapRequest = T.SwapRequest;
  type SwapResult = T.SwapResult;

  let nhash = Map.n64hash;
  let ntn_ledger = actor ("f54if-eqaaa-aaaaq-aacea-cai") : Ledger.Self;

  // let neutrinite_treasury : Ledger.Account = {
  //   owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
  //   subaccount = ?"\61\47\4b\07\1a\86\0b\27\95\75\c9\54\ce\5f\35\98\f4\f8\63\f8\c6\f4\50\86\0c\d3\c3\11\43\16\ef\2d" : ?Blob;
  // };

  let whitelisted = Principal.fromText("lovjp-a2s3z-lqgmk-epyel-hshnr-ksdzf-abimc-f7dpu-33z4u-2vbkf-uae");

  stable let _dvectors = Map.new<DVectorId, DVector>();
  stable var _nextDVectorId : DVectorId = 0;

  stable var _ICPBTC : Float = 0.0;

  let exchange_rate_canister : XRC.Self = actor ("uf6dk-hyaaa-aaaaq-qaaaq-cai");

  // Transfer NTN from account using icrc2, trap on error
  // private func require_ntn_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async () {
  //   switch (await ntn_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
  //     case (#Ok(_))();
  //     case (#Err(e)) Debug.trap(debug_show (e));
  //   };
  // };

  // public shared ({caller}) func update_all_dvectors() : async () {
  //   assert (caller == whitelisted);

  //   let dvectors = Map.entries(_dvectors);
  //   for (dvector in dvectors) {
  //     await update_dvector_status(dvector.0);
  //   };
  // };

  // When there are dvectors in opposite directions, match them
  private func match_settlement(pid : DVectorId) : () {
    let ?dvector = Map.get(_dvectors, nhash, pid) else Debug.trap("no such dvector");

    let other = Map.entries(_dvectors);
    for ((oid, odvector) in other) {
      if (dvector.destination.ledger == odvector.source.ledger) {
        switch (Vector.indexOf<DVectorId>(oid, dvector.settlement, Nat64.equal)) {
          case (?found)();
          case (null) Vector.add(dvector.settlement, oid);
        };
      };
      if (odvector.destination.ledger == dvector.source.ledger) {
        switch (Vector.indexOf<DVectorId>(pid, odvector.settlement, Nat64.equal)) {
          case (?found)();
          case (null) Vector.add(odvector.settlement, pid);
        };
      };
    };
  };

  public func settle_dvectors(pid : DVectorId, oid : DVectorId) : async R<(), Text> {
    await settle(pid, oid);
  };

  private func get_dvector_rate(dvector: DVector) : Float {
    switch(dvector.rate.provider) {
        case (#xrc(x)) {
          if (x.source == "ICP" and x.destination == "BTC") {
            _ICPBTC;
          } else if (x.source == "BTC" and x.destination == "ICP") {
            1/_ICPBTC;
          } else {
            Debug.trap("unsupported xrc rate")
          }
        };
      }
  };

  private func settle(pid : DVectorId, oid : DVectorId) : async R<(), Text> {
    let ?dvector = Map.get(_dvectors, nhash, pid) else Debug.trap("no such dvector");

    let ?odvector = Map.get(_dvectors, nhash, oid) else Debug.trap("no such settlement dvector");

    ignore do ? {
      let balance = dvector.source_balance;

      let rate = get_dvector_rate(dvector);

      let obalance = dvector.source_balance;
      
      let orate = get_dvector_rate(odvector);

      let calcrate = 1 / rate;

      let amount_t1_swap = Nat.max(Nat.min(balance / 10, 300_000), 10 * dvector.source.ledger_fee);

      if (balance < amount_t1_swap + dvector.source.ledger_fee) {
        return #err("insufficient balance p1. required " # debug_show (amount_t1_swap));
      };

      let amount_t2_swap : Nat = T.natAmount(T.floatAmount(balance, dvector.source.ledger_decimals) / rate, odvector.source.ledger_decimals);

      if (obalance < amount_t2_swap + odvector.source.ledger_fee) {
        return #err("insufficient balance p2. required " # debug_show (amount_t2_swap));
      };

      // Allow 0.1% slippage between the two rates
      if (calcrate < orate * 0.999 or calcrate > orate * 1.001) {
        return #err("rate mismatch " # debug_show (orate) # " - " # debug_show (calcrate));
      };

      // Transfer from one dvector to another
      let source_ledger = actor (Principal.toText(dvector.source.ledger)) : Ledger.Oneway;
      let destination_ledger = actor (Principal.toText(dvector.destination.ledger)) : Ledger.Oneway;

      source_ledger.icrc1_transfer({
        to = odvector.destination.address;
        from_subaccount = dvector.source.address.subaccount;
        amount = amount_t1_swap - dvector.source.ledger_fee;
        memo = null;
        created_at_time = null;
        fee = null;
      });

      destination_ledger.icrc1_transfer({
        to = dvector.destination.address;
        from_subaccount = odvector.source.address.subaccount;
        amount = amount_t2_swap - odvector.source.ledger_fee;
        memo = null;
        created_at_time = null;
        fee = null;
      });

    };

    #ok();

  };

  public shared ({ caller }) func create_dvector(req : DVectorRequest) : async R<DVectorId, Text> {

    assert (caller == whitelisted);

    // await require_ntn_transfer(
    //   caller,
    //   req.initiator_collateral,
    //   {
    //     owner = Principal.fromActor(this);
    //     subaccount = ?T.getPrincipalSubaccount(caller);
    //   },
    // );

    let pid = _nextDVectorId;
    _nextDVectorId += 1;

    let source_ledger_meta = await T.ledgerMeta(req.source.ledger);
    let destination_ledger_meta = await T.ledgerMeta(req.destination.ledger);

    let source_ledger = actor (Principal.toText(dvector.source.ledger)) : Ledger.Self;
    let destination_ledger = actor (Principal.toText(dvector.destination.ledger)) : Ledger.Self;

    let source : Endpoint = {
      ledger = req.source.ledger;
      address = {
        owner = Principal.fromActor(this);
        subaccount = ?T.getDVectorSubaccount(pid, #source);
      } : Ledger.Account;
      ledger_decimals = source_ledger_meta.decimals;
      ledger_fee = source_ledger_meta.fee;
      ledger_symbol = source_ledger_meta.symbol;
    };

    let destination : Endpoint = {
      ledger = req.destination.ledger;
      address = Option.get(
        req.destination.address,
        {
          owner = Principal.fromActor(this);
          subaccount = ?T.getDVectorSubaccount(pid, #destination);
        } : Ledger.Account,
      );
      ledger_decimals = destination_ledger_meta.decimals;
      ledger_fee = destination_ledger_meta.fee;
      ledger_symbol = destination_ledger_meta.symbol;
    };

    let dvector : DVector = {
      owner = req.owner;
      rate = req.rate;
      created = T.now();
      source;
      var source_balance = await source_ledger.icrc1_balance_of(source.address);
      var destination_balance = await destination_ledger.icrc1_balance_of(destination.address);
      destination;
      settlement = Vector.new<DVectorId>();
    };

    Map.set(_dvectors, nhash, pid, dvector);

    match_settlement(pid);

    #ok pid;
  };

  public query func get_dvector(pid : DVectorId) : async ?DVectorShared {
    T.DVector.toShared(Map.get(_dvectors, nhash, pid));
  };

  // public shared ({ caller }) func update_dvector(pid : DVectorId) : async () {
  //   assert (caller == whitelisted);
  //   await update_dvector_status(pid);
  // };

  // private func update_dvector_status(pid : DVectorId) : async () {
  //   let ?dvector = Map.get(_dvectors, nhash, pid) else Debug.trap("no such dvector");

  //   let source_ledger = actor (Principal.toText(dvector.source.ledger)) : Ledger.Self;
  //   let destination_ledger = actor (Principal.toText(dvector.destination.ledger)) : Ledger.Self;

  //   // let source_balance = await source_ledger.icrc1_balance_of(dvector.source.address);

  //   // let destination_balance = await destination_ledger.icrc1_balance_of(dvector.destination.address);

  //   // requested_rate from XRC
  //   let rate = switch (dvector.rate.provider) {
  //     case (#xrc(x)) {
  //       await get_xrc_rate(x.source, x.destination);
  //     };
  //     //...
  //   };

  //   // calculate rate from balances
  //   let provided_rate = T.getFloatRate(dvector.source_balance, dvector.source.ledger_decimals, dvector.destination_balance, dvector.destination.ledger_decimals);

  //   // if source is mismatching check if matching
  //   let rate_in_range = rate < dvector.rate.max;
  //   // let destination_min_calc_required = Int.abs(Float.toInt((T.floatRateFromNat(source_balance, dvector.source.ledger_decimals) * Float.min(rate, dvector.rate.max))*Float.fromInt(10**dvector.destination.ledger_decimals)));

  //   dvector.status := ?{
  //     rate;
  //     active = rate_in_range;
  //   };

  // };


  private func update_xrc_rates() : async () {
    _ICPBTC := await get_xrc_rate("ICP", "BTC");
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


  ignore Timer.recurringTimer(#seconds 300, update_xrc_rates);

  Timer.setTimer(#seconds 0, update_xrc_rates);

  
};
