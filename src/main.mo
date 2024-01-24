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
import Rates "./rates";
import LedgerMeta "./ledgermeta";
import Matching "./matching";
import IndexerICRC "./indexers/icrc";
import IndexerICP "./indexers/icp";
import Sender "./sender";
import History "./history";
import Architect "./architect";

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

  let nhash = Map.n32hash;
  let NTN_ledger = actor ("f54if-eqaaa-aaaaq-aacea-cai") : Ledger.Self;
  let ICP_ledger = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
  let BTC_ledger = Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai");
  // let neutrinite_treasury : Ledger.Account = {
  //   owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
  //   subaccount = ?"\61\47\4b\07\1a\86\0b\27\95\75\c9\54\ce\5f\35\98\f4\f8\63\f8\c6\f4\50\86\0c\d3\c3\11\43\16\ef\2d" : ?Blob;
  // };

  let whitelisted = Principal.fromText("lovjp-a2s3z-lqgmk-epyel-hshnr-ksdzf-abimc-f7dpu-33z4u-2vbkf-uae");

  stable let _dvectors = Map.new<DVectorId, DVector>();
  stable var _nextDVectorId : DVectorId = 0;
  stable var _architects_mem : Architect.ArchMem = {
    architects = Map.new<Principal, Vector.Vector<T.DVectorId>>();
  };

  stable let _history_mem = Vector.new<T.History.Tx>();

  let _history = History.History({
    mem = _history_mem
  });

  let _errlog = Vector.new<Text>();

  let _ledgermeta = LedgerMeta.LedgerMeta({
    ledgers = [ICP_ledger, BTC_ledger]
  });
  
  let _rates = Rates.Rates({
    whitelisted = [
      // id in defiaggregator config, ledger
      (1, ICP_ledger), // ICP
      (3, BTC_ledger) // BTC
    ]
  });

  // ---

  let _matching_mem : Matching.MatchingMem = {
    var last_tx_id = 0;
  };

  let _matching = Matching.Matching({
    mem = _matching_mem;
    rates = _rates;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
  });

  // ---

  let _indexer_ckBTC_mem : IndexerICRC.Mem = {
    var last_indexed_tx = 0; // leave 0 to start from the last one
    source2vector = Map.new<Ledger.Account, DVectorId>();
    destination2vector = Map.new<Ledger.Account, DVectorId>();
    var paused = false;
  };

  let _indexer_ckBTC = IndexerICRC.Indexer({
    ledger_id = BTC_ledger;
    mem = _indexer_ckBTC_mem;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
  });

  // ---

  let _indexer_ICP_mem : IndexerICP.Mem = {
    var last_indexed_tx = 0; // leave 0 to start from the last one
    source2vector = Map.new<Blob, DVectorId>();
    destination2vector = Map.new<Blob, DVectorId>();
    var paused = false;
  };

  let _indexer_ICP = IndexerICP.Indexer({
    ledger_id = ICP_ledger;
    mem = _indexer_ICP_mem;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
  });

  // --- 

  let _sender = Sender.Sender({
    errlog = _errlog;
    dvectors = _dvectors;
    history = _history;
  });

  // ---
  let _architects = Architect.Architect({
    mem = _architects_mem;
    dvectors = _dvectors;
    history_mem = _history_mem;
  });


  ignore Timer.setTimer(#seconds 1, func () : async () {
    // Some timers were not starting when directly placed in classes
  
    _sender.start_timer();
    _indexer_ckBTC.start_timer();
    _indexer_ICP.start_timer();
  });

  ignore Timer.setTimer(#seconds 1, func () : async () {
    // Some timers were not starting when directly placed in classes
    _ledgermeta.start_timer();
    _rates.start_timer();
    _matching.start_timer();

  });


  // Transfer NTN from account using icrc2, trap on error
  // private func require_ntn_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async () {
  //   switch (await ntn_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
  //     case (#Ok(_))();
  //     case (#Err(e)) Debug.trap(debug_show (e));
  //   };
  // };

  public query func stats() : async [Nat] {
    [
      _indexer_ICP_mem.last_indexed_tx,
      _indexer_ckBTC_mem.last_indexed_tx
    ]
  };

  public shared ({ caller }) func create_vector(req : DVectorRequest) : async R<DVectorId, Text> {

    assert (caller == whitelisted);

    // await require_ntn_transfer(
    //   caller,
    //   req.initiator_collateral,
    //   {
    //     owner = Principal.fromActor(this);
    //     subaccount = ?T.getPrincipalSubaccount(caller);
    //   },
    // );


    let ?source_ledger_meta = _ledgermeta.get(req.source.ledger) else return #err("source ledger meta not found");
    let ?destination_ledger_meta = _ledgermeta.get(req.destination.ledger) else return #err("destination ledger meta not found");

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
      algorate = req.algorate;
      var active = false;
      var rate = 0;
      created = T.now();
      source;
      var source_balance = await source_ledger.icrc1_balance_of(source.address);
      var amount_available = 0;
      var destination_balance = await destination_ledger.icrc1_balance_of(destination.address);
      destination;
      var unconfirmed_transactions = [];
      history = Vector.new<T.History.TxId>();
    };

    Map.set(_dvectors, nhash, pid, dvector);
    _architects.add_vector(caller, pid);
    _indexer_ICP.register_vector(pid, dvector);
    _indexer_ckBTC.register_vector(pid, dvector);

    #ok pid;
  };

  public query func get_vector(pid : DVectorId) : async ?DVectorShared {
    T.DVector.toShared(_history_mem, Map.get(_dvectors, nhash, pid));
  };

  public query func get_architect_vectors({id: Principal; start:Nat; length:Nat}) : async Architect.ArchVectorsResult {
    _architects.get_vectors(id, start, length);
  };

  public query func get_events({start:Nat; length:Nat}) : async R<T.History.HistoryResponse, Text> {
    let total = Vector.size(_history_mem);
    let real_len = Nat.min(length, if (start > length) 0 else total - start);

    let entries = Array.tabulate<(T.History.TxId, T.History.Tx)>(real_len, func (i) {
            let id = start + i;
            let tx = Vector.get(_history_mem, id);
            (id, tx);
        });
    #ok {
      total;
      entries;
    }
  };

  public query func get_vector_events({id: T.DVectorId; start: Nat; length: Nat}) : async R<T.History.HistoryResponse, Text> {
    let ?vector = Map.get(_dvectors, nhash, id) else return #err("vector not found");

    let total = Vector.size(vector.history);

    let real_len = Nat.min(length, if (start > length) 0 else total - start);

    let entries = Array.tabulate<(T.History.TxId, T.History.Tx)>(real_len, func (i) {
            let id = start + i;
            let tx = Vector.get(_history_mem, id);
            (id, tx);
        });
        
    #ok {
      total;
      entries;
    }
  };

  public query func show_log() : async [Text] {
    Vector.toArray(_errlog);
  };

  public func index_pause(paused: Bool) : async () {
    _indexer_ckBTC_mem.paused := paused;
    _indexer_ICP_mem.paused := paused;
  }
  
};
