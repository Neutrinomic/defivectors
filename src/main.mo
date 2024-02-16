import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Ledger "./services/icrc_ledger";
import IcpLedger "./services/icp_ledger";

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
import Rates "./rates";
import LedgerMeta "./ledgermeta";
import Matching "./matching";
import IndexerICRC "./indexers/icrc";
import IndexerICP "./indexers/icp";
import Sender "./sender";
import History "./history";
import Architect "./architect";
import Monitor "./monitor";

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

  let nhash = Map.n32hash;

  let VECTOR_NTN_cost = 4_0000_0000;
  let NTN_ledger_id = Principal.fromText("f54if-eqaaa-aaaaq-aacea-cai");
  let ICP_ledger_id = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
  let NTN_ledger = actor (Principal.toText(NTN_ledger_id)) : Ledger.Self;
  let ICP_ledger = actor (Principal.toText(ICP_ledger_id)) : IcpLedger.Self;

  let LEFT_ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
  let RIGHT_ledger = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");

  // let whitelisted = Principal.fromText("lovjp-a2s3z-lqgmk-epyel-hshnr-ksdzf-abimc-f7dpu-33z4u-2vbkf-uae");
  let gov_canister_id = Principal.fromText("z45mi-3hwqo-bsda6-saeqm-fambt-gp7rn-aynd3-v4oga-dfe24-voedf-mae");

  stable let _dvectors = Map.new<DVectorId, DVector>();
  stable var _nextDVectorId : DVectorId = 0;
  stable let _architects_mem : Architect.ArchMem = {
    architects = Map.new<Principal, Vector.Vector<T.DVectorId>>();
  };

  stable let _history_mem = Vector.new<T.History.Tx>();

  let _monitor = Monitor.Monitor();

  let _history = History.History({
    mem = _history_mem;
  });

  let _errlog = Vector.new<Text>();

  let _ledgermeta = LedgerMeta.LedgerMeta({
    ledgers = [LEFT_ledger, RIGHT_ledger];
  });

  let _rates = Rates.Rates({
    whitelisted = [
      // id in defiaggregator config, ledger
      (3, LEFT_ledger), // ICP
      (1, RIGHT_ledger), // BTC
      (30, NTN_ledger_id) // NTN
    ];
  });

  // ---

  stable let _matching_mem : Matching.MatchingMem = {
    var last_tx_id = 0;
  };

  let _matching = Matching.Matching({
    mem = _matching_mem;
    rates = _rates;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
    monitor = _monitor;
    ledger_left = LEFT_ledger;
    ledger_right = RIGHT_ledger;
  });

  // ---

  stable let _indexer_right_mem : IndexerICRC.Mem = {
    var last_indexed_tx = 0; // leave 0 to start from the last one
    source2vector = Map.new<Ledger.Account, DVectorId>();
    destination2vector = Map.new<Ledger.Account, DVectorId>();
    var paused = false;
  };

  let _indexer_right = IndexerICRC.Indexer({
    ledger_id = RIGHT_ledger;
    mem = _indexer_right_mem;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
    monitor = _monitor;
    metric_key = Monitor.INDEXER_RIGHT;
  });

  // ---

  stable let _indexer_left_mem : IndexerICP.Mem = {
    var last_indexed_tx = 0; // leave 0 to start from the last one
    source2vector = Map.new<Blob, DVectorId>();
    destination2vector = Map.new<Blob, DVectorId>();
    var paused = false;
  };

  let _indexer_left = IndexerICP.Indexer({
    ledger_id = LEFT_ledger;
    mem = _indexer_left_mem;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
    monitor = _monitor;
    metric_key = Monitor.INDEXER_LEFT;
  });

  // ---

  let _sender = Sender.Sender({
    errlog = _errlog;
    dvectors = _dvectors;
    history = _history;
    monitor = _monitor;
  });

  // ---

  let _architects = Architect.Architect({
    mem = _architects_mem;
    dvectors = _dvectors;
    history_mem = _history_mem;
  });


  // --- Start timers
  var timer_to_start = 0;
  let timers :[() -> ()] = [
      func () { _sender.start_timer() },
      func () { _indexer_right.start_timer() },
      func () { _indexer_left.start_timer() },
      func () { _ledgermeta.start_timer() },
      func () { _rates.start_timer() },
      func () { _matching.start_timer() },
  ];

  private func start_timers() : async () {
      timers[timer_to_start]();
      timer_to_start += 1;
      if (timer_to_start < timers.size()) ignore Timer.setTimer( #seconds 1, start_timers );
  };

  ignore Timer.setTimer( #seconds 1, start_timers );

  // ---

  // Transfer NTN from account using icrc2, trap on error
  private func require_ntn_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async R<(), Text> {
    switch (await NTN_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
      case (#Ok(_)) #ok();
      case (#Err(e)) #err(debug_show(e));
    };
  };

  // Transfer ICP from account using icrc2, trap on error
  private func require_icp_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async R<(), Text> {
    switch (await NTN_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
      case (#Ok(_)) #ok();
      case (#Err(e)) #err(debug_show(e));
    };
  };

  public shared ({ caller }) func modify_vector(req : T.DVectorChangeRequest) : async R<(), Text> {
    let ?vector = Map.get(_dvectors, nhash, req.id) else return #err("vector not found");
    if (caller != vector.owner) return #err("caller is not the owner");
    
    let local_address = {
          owner = Principal.fromActor(this);
          subaccount = ?T.getDVectorSubaccount(req.id, #destination);
          } : Ledger.Account;

    switch(req.destination) {
      case (#unchanged) ();
      case (#set(addr)) {
        if (vector.destination_balance_available != vector.destination_balance) return #err("Can't change destination when tokens are in transit from the destination address");
        if ((not vector.remote_destination) and vector.destination_balance != 0) return #err("You have to withdraw everything from destination balance before changing the destination address"); // or we users can't withdraw it anymore
        if (local_address == addr) return #err("You shouldn't set the remote address to be the local address. Try clear instead");
        if (not T.is_valid_account(addr)) return #err("Destination address is not valid");
        if (addr == vector.destination.address) return #err("Destination address is the same");

        vector.destination_balance := 0;
        vector.destination_balance_available := 0;
        vector.destination := {vector.destination with address = addr}; 
        vector.remote_destination := true;
      };
      case (#clear) {
        if (vector.destination.address == local_address) return #err("Already using the vector's local address");

        vector.remote_destination := false;
        vector.destination := {vector.destination with address = local_address };
        vector.destination_balance := 0;
        vector.destination_balance_available := 0;
      }
    };

    vector.algo := req.algo;

    vector.modified := T.now();
    #ok();
  };


  public shared ({ caller }) func create_vector(req : DVectorRequest, payment_token:{#icp; #ntn}) : async R<DVectorId, Text> {

    let ?source_ledger_meta = _ledgermeta.get(req.source.ledger) else return #err("source ledger meta not found");
    let ?destination_ledger_meta = _ledgermeta.get(req.destination.ledger) else return #err("destination ledger meta not found");

    if (req.source.ledger == req.destination.ledger) return #err("source and destination ledgers are the same");
    if (req.source.ledger != LEFT_ledger and req.source.ledger != RIGHT_ledger) return #err("ledger is not supported in this factory");
    if (req.destination.ledger != LEFT_ledger and req.destination.ledger != RIGHT_ledger) return #err("ledger is not supported in this factory");
    ignore do ? {
      if (not T.is_valid_account(req.destination.address!)) return #err("destination address is not valid");
    };

    // Payment
    if (caller != gov_canister_id) {
      switch(payment_token) {
        case (#icp) {

          let ?ntn_usd_price = _rates.get_rate(NTN_ledger_id) else return #err("NTN price not found");
          let ?icp_usd_price = _rates.get_rate(ICP_ledger_id) else return #err("ICP price not found");
          let vector_cost_ICP = T.natAmount( T.floatAmount(VECTOR_NTN_cost, 8) * ntn_usd_price / icp_usd_price, 8);
          switch(await require_icp_transfer(
                caller,
                vector_cost_ICP,
                {
                  owner = Principal.fromActor(this);
                  subaccount = null;
                },
              )) {
                case (#ok()) ();
                case (#err(e)) return #err(e);
              };
        };

        case (#ntn) {
          switch(await require_ntn_transfer(
                caller,
                VECTOR_NTN_cost,
                {
                  owner = Principal.fromActor(this);
                  subaccount = null;
                },
              )) {
                case (#ok()) ();
                case (#err(e)) return #err(e);
              };
        }
      };

   
    };

    let source_ledger = actor (Principal.toText(req.source.ledger)) : Ledger.Self;
    let destination_ledger = actor (Principal.toText(req.destination.ledger)) : Ledger.Self;
   
    let pid = _nextDVectorId;
    _nextDVectorId += 1;

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
      owner = caller;
      var algo = req.algo;
      var active = false;
      var rate = 0;
      created = T.now();
      var modified = T.now();
      source;
      var source_balance = await source_ledger.icrc1_balance_of(source.address);
      var source_balance_available = 0;
      var source_balance_tradable = 0;
      var source_balance_tradable_last_update = T.now();
      var destination_balance = await destination_ledger.icrc1_balance_of(destination.address);
      var source_rate_usd = 0;
      var destination_rate_usd = 0;
      var destination_balance_available = 0;
      var destination = destination;
      var unconfirmed_transactions = [];
      history = Vector.new<T.History.TxId>();
      var remote_destination = req.destination.address != null
    };

    Map.set(_dvectors, nhash, pid, dvector);
    _architects.add_vector(caller, pid);
    _indexer_left.register_vector(pid, dvector);
    _indexer_right.register_vector(pid, dvector);

    #ok pid;
  };

  public query func get_vector(pid : DVectorId) : async ?DVectorShared {
    T.DVector.toShared(_history_mem, Map.get(_dvectors, nhash, pid));
  };

  public query({caller}) func get_architect_vectors({
    id : Principal;
    start : Nat;
    length : Nat;
  }) : async Architect.ArchVectorsResult {
    _architects.get_vectors(id, start, length, caller);
  };

  public query func get_vector_price() : async R<{icp:Nat; ntn:Nat}, Text> {

    let ?ntn_usd_price = _rates.get_rate(NTN_ledger_id) else return #err("NTN price not found");
    let ?icp_usd_price = _rates.get_rate(ICP_ledger_id) else return #err("ICP price not found");
    let vector_cost_ICP = T.natAmount( T.floatAmount(VECTOR_NTN_cost, 8) * ntn_usd_price / icp_usd_price, 8);

    #ok {
      icp = vector_cost_ICP;
      ntn = VECTOR_NTN_cost;
    };
  };

  public query func get_events({ start : Nat; length : Nat }) : async R<T.History.HistoryResponse, Text> {
    let total = Vector.size(_history_mem);
    let real_len = Nat.min(length, if (start > total) 0 else total - start);

    let entries = Array.tabulate<(T.History.TxId, T.History.Tx)>(
      real_len,
      func(i) {
        let id = start + i;
        let tx = Vector.get(_history_mem, id);
        (id, tx);
      },
    );
    #ok {
      total;
      entries;
    };
  };

  public query func get_vector_events({
    id : T.DVectorId;
    start : Nat;
    length : Nat;
  }) : async R<T.History.HistoryResponse, Text> {
    let ?vector = Map.get(_dvectors, nhash, id) else return #err("vector not found");

    let total = Vector.size(vector.history);

    let real_len = Nat.min(length, if (start >= total) 0 else total - start); 

    let entries = Array.tabulate<(T.History.TxId, T.History.Tx)>(
      real_len,
      func(i) {
        let lid = start + i;
        let id = Vector.get(vector.history, lid);
        let tx = Vector.get(_history_mem, id);
        (id, tx);
      },
    );

    #ok {
      total;
      entries;
    };
  };

  public shared ({ caller }) func withdraw_vector({
    id : T.DVectorId;
    to : Ledger.Account;
    amount : Nat;
    location : T.VLocation;
  }) : async R<Nat64, Text> {

    let ?vector = Map.get(_dvectors, nhash, id) else return #err("vector not found");
    if (caller != vector.owner) return #err("caller is not the owner");
    switch (location) {
      case (#source) {
          if (amount <= vector.source.ledger_fee * 10) return #err("amount is too low");
      };
      case (#destination) {
          // Double check if the destination is the destination of this vector
          // if not - it could be the source of another vector
          // in which case we have to deny the withdraw
          let vector_destination = {
            owner = Principal.fromActor(this);
            subaccount = ?T.getDVectorSubaccount(id, #destination);
          } : Ledger.Account;
          
          if (vector.remote_destination or vector_destination != vector.destination.address) return #err("destination is the source of another vector or remote");
          if (amount <= vector.destination.ledger_fee * 10) return #err("amount is too low");
      };
    };

    #ok(_matching.make_withdraw_transaction(id, vector, amount, to, location));
  };

  public query func show_log() : async [Text] {
    Vector.toArray(_errlog);
  };

  // public func index_pause(paused : Bool) : async () {
  //   // TODO: security remove
  //   _indexer_right_mem.paused := paused;
  //   _indexer_left_mem.paused := paused;
  // };

  type SnapshotResponse = {
    monitor: [Monitor.Metric];
  };

  public query func monitor_snapshot() : async SnapshotResponse {
    {
      monitor =_monitor.snapshot();
      indexed_left = _indexer_left_mem.last_indexed_tx;
      indexed_right = _indexer_right_mem.last_indexed_tx;
    }
  }

};
