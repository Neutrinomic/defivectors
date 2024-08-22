import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Ledger "./services/icrc_ledger";
import IcpLedger "./services/icp_ledger";

import Map "mo:map/Map";
import T "./types";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Vector "mo:vector";
import Nat "mo:base/Nat";
import Rates "./rates";
import LedgerMeta "./ledgermeta";
import Matching "./matching";
import IndexerICRC "./indexers/icrc";
import IndexerICP "./indexers/icp";
import Sender "./sender";
import History "./history";
import Architect "./architect";
import Monitor "./monitor";
import SWB "mo:swbstable/Stable";
import ErrLog "./errlog";
import Rechain "mo:rechain";
import RechainT "./rechain_types";
import Timer "mo:base/Timer";
import PairMarketData "mo:icrc45";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Info "./info";
import ExperimentalCycles "mo:base/ExperimentalCycles";

actor class Swap({
        NTN_ledger_id;
        ICP_ledger_id;
        LEFT_ledger;
        RIGHT_ledger;
        DEFI_AGGREGATOR;
        LEFT_aggr_id;
        RIGHT_aggr_id;
        } : T.InitArg) = this {
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
  
  let NTN_ledger = actor (Principal.toText(NTN_ledger_id)) : Ledger.Self;
  let ICP_ledger = actor (Principal.toText(ICP_ledger_id)) : IcpLedger.Self;

  let gov_canister_id = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"); // Neutrinite DAO
  let gov_canister_treasury = "\61\47\4b\07\1a\86\0b\27\95\75\c9\54\ce\5f\35\98\f4\f8\63\f8\c6\f4\50\86\0c\d3\c3\11\43\16\ef\2d":Blob;
  let dev_id = Principal.fromText("aojy2-p2wmt-4pvbt-rslzv-2clzy-n7t2s-7u7dd-xw6op-zk6kx-vv5ju-lae"); // Developers

  // Rechain

  stable let chain_mem  = Rechain.Mem();
  var rechain = Rechain.Chain<RechainT.Action, RechainT.ActionError>({
      settings = ?{Rechain.DEFAULT_SETTINGS with supportedBlocks = [{
        block_type = "47exchange";
        url = "https://github.com/Neutrinomic/wg_defi/blob/main/icrc-47/ICRC47.md";
      }]};
      mem = chain_mem;
      encodeBlock = RechainT.encodeBlock;
      reducers = [];
  });

  stable let _dvectors = Map.new<DVectorId, DVector>();
  stable var _nextDVectorId : DVectorId = 0;
  stable let _architects_mem : Architect.ArchMem = {
    architects = Map.new<Principal, Vector.Vector<T.DVectorId>>();
  };

  stable let _history_mem = SWB.SlidingWindowBufferNewMem<T.History.Tx>();
  let _history_cls = SWB.SlidingWindowBuffer<T.History.Tx>(_history_mem);
  let _monitor = Monitor.Monitor();

  let _history = History.History({
    mem = _history_cls;
  });

  stable let _errlog_mem = SWB.SlidingWindowBufferNewMem<Text>();
  let _errlog_cls = SWB.SlidingWindowBuffer<Text>(_errlog_mem);
  let _errlog = ErrLog.ErrLog({
    mem = _errlog_cls;
  });

  let _ledgermeta = LedgerMeta.LedgerMeta({
    ledgers = [LEFT_ledger, RIGHT_ledger];
  });

  let _rates = Rates.Rates({
    DEFI_AGGREGATOR;
    whitelisted = [
      // id in defiaggregator config, ledger
      (LEFT_aggr_id, LEFT_ledger), 
      (RIGHT_aggr_id, RIGHT_ledger), 
      (30, NTN_ledger_id) // NTN
    ];
  });

  // --- ICRC45
  let _my_pair_id : PairMarketData.PairId = {
      base = {platform = 1; path = Principal.toBlob(LEFT_ledger)};
      quote = {platform = 1; path = Principal.toBlob(RIGHT_ledger)};
    };
  stable let _market_data_mem = PairMarketData.Mem();
  let _market_data = PairMarketData.PairMarketData({
    mem = _market_data_mem;
    id = _my_pair_id;
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
    market_data = _market_data;
    rechain;
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

  stable let _indexer_left_mem_icrc : IndexerICRC.Mem = {
    var last_indexed_tx = 0; // leave 0 to start from the last one
    source2vector = Map.new<Ledger.Account, DVectorId>();
    destination2vector = Map.new<Ledger.Account, DVectorId>();
    var paused = false;
  };

  // ICP ledger is not ICRC, so we need another indexer
  let _indexer_left = if (LEFT_ledger == ICP_ledger_id) IndexerICP.Indexer({
    ledger_id = LEFT_ledger;
    mem = _indexer_left_mem;
    dvectors = _dvectors;
    errlog = _errlog;
    history = _history;
    monitor = _monitor;
    metric_key = Monitor.INDEXER_LEFT;
  }) else IndexerICRC.Indexer({
    ledger_id = LEFT_ledger;
    mem = _indexer_left_mem_icrc;
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
  });


  // --- Start timers
  _sender.start_timer<system>();
  _indexer_right.start_timer<system>();
  _indexer_left.start_timer<system>();
  _ledgermeta.start_timer<system>();
  _rates.start_timer<system>();
  _matching.start_timer<system>();
  // Rechain timers
  ignore Timer.setTimer<system>(#seconds 0, func () : async () {
      await rechain.start_archiving<system>();

      // Tops up all archive canisters with cycles
      await rechain.start_archiveCycleMaintenance<system>();

  });
  // Autoupgrade ICRC3 archives every time this canister is upgraded
  ignore Timer.setTimer<system>(#seconds 1, func () : async () {
      await rechain.upgrade_archives();
  });
  // ---
  // TEMPORARY: Fix corrupted memory caused by the withdrawal bug
  if (RIGHT_ledger == Principal.fromText("buwm7-7yaaa-aaaar-qagva-cai")) {
    ignore Timer.setTimer<system>(#seconds 10, func() : async () {
      let nICP_ledger = actor (Principal.toText(RIGHT_ledger)) : Ledger.Self;
      let ?vec = Map.get(_dvectors, nhash, 5:DVectorId) else return ();
      vec.destination_balance := await nICP_ledger.icrc1_balance_of(vec.destination.address);
    });
  };
  // ---

  let _info = Info.Info();

  // Transfer NTN from subaccount using icrc1, trap on error. Useful for SNSes paying for vectors
  private func require_ntn_dao_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async R<(), Text> {
    switch (await NTN_ledger.icrc1_transfer({ to = reciever; fee = null; memo = null; from_subaccount = ?T.callerSubaccount(from); created_at_time = null; amount = amount })) {
      case (#Ok(_)) #ok();
      case (#Err(e)) #err(debug_show(e));
    };
  };

  // Transfer NTN from account using icrc2, trap on error
  private func require_ntn_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async R<(), Text> {
    switch (await NTN_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
      case (#Ok(_)) #ok();
      case (#Err(e)) #err(debug_show(e));
    };
  };

  // Transfer ICP from account using icrc2, trap on error
  private func require_icp_transfer(from : Principal, amount : Nat, reciever : Ledger.Account) : async R<(), Text> {
    switch (await ICP_ledger.icrc2_transfer_from({ from = { owner = from; subaccount = null }; spender_subaccount = null; to = reciever; fee = null; memo = null; from_subaccount = null; created_at_time = null; amount = amount })) {
      case (#Ok(_)) #ok();
      case (#Err(e)) #err(debug_show(e));
    };
  };

  public query func validate_modify_vector(req : T.DVectorChangeRequest): async T.SNSValidationResult {
    #Ok(debug_show(req));
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

  public query func validate_create_vector(req : DVectorRequest, payment_token:{#icp; #ntn; #ntndao}): async T.SNSValidationResult {
    let daddress :Text = switch(req.destination.address) {
        case (null) "none";
        case (?{owner; subaccount}) Principal.toText(owner) # " " # debug_show(subaccount);
      };
    if (payment_token != #ntndao) return #Err("You can only pay using the #ntndao payment option");

    let msg = "
      Creating new vector:
      Source ledger: " # Principal.toText(req.source.ledger) # "
      Destination ledger: " # Principal.toText(req.destination.ledger) # "
      Destination address: " # daddress # "
      Payment token: " # debug_show(payment_token) # ";
      Request: " # debug_show(req) # ";
    ";
    #Ok(msg);

  };

  public shared ({ caller }) func create_vector(req : DVectorRequest, payment_token:{#icp; #ntn; #ntndao}) : async R<DVectorId, Text> {

    let ?source_ledger_meta = _ledgermeta.get(req.source.ledger) else return #err("source ledger meta not found");
    let ?destination_ledger_meta = _ledgermeta.get(req.destination.ledger) else return #err("destination ledger meta not found");

    if (req.source.ledger == req.destination.ledger) return #err("source and destination ledgers are the same");
    if (req.source.ledger != LEFT_ledger and req.source.ledger != RIGHT_ledger) return #err("ledger is not supported in this factory");
    if (req.destination.ledger != LEFT_ledger and req.destination.ledger != RIGHT_ledger) return #err("ledger is not supported in this factory");
    ignore do ? {
      if (not T.is_valid_account(req.destination.address!)) return #err("destination address is not valid");
    };

    // Payment

    if (caller != gov_canister_id and caller != dev_id) {
      switch(payment_token) {
        case (#icp) {

          let ?ntn_usd_price = _rates.get_rate(NTN_ledger_id) else return #err("NTN price not found");
          let ?icp_usd_price = _rates.get_rate(ICP_ledger_id) else return #err("ICP price not found");
          let vector_cost_ICP = T.natAmount( T.floatAmount(VECTOR_NTN_cost, 8) * ntn_usd_price / icp_usd_price, 8);
          switch(await require_icp_transfer(
                caller,
                vector_cost_ICP,
                {
                  owner = gov_canister_id;
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
                  owner = gov_canister_id;
                  subaccount = ?gov_canister_treasury;
                },
              )) {
                case (#ok()) ();
                case (#err(e)) return #err(e);
              };
        };

        case (#ntndao) {
          switch(await require_ntn_dao_transfer(
                caller,
                VECTOR_NTN_cost,
                {
                  owner = gov_canister_id;
                  subaccount = ?gov_canister_treasury;
                },
              )) {
                case (#ok()) ();
                case (#err(e)) return #err(e);
              };
        }

      };

    };

   
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
      var source_balance = 0;
      var source_balance_available = 0;
      var source_balance_tradable = 0;
      var source_balance_tradable_last_update = T.now();
      var destination_balance = 0;
      var source_rate_usd = 0;
      var destination_rate_usd = 0;
      var destination_balance_available = 0;
      var destination = destination;
      var unconfirmed_transactions = [];
      history = SWB.SlidingWindowBufferNewMem<T.History.TxId>();
      var remote_destination = req.destination.address != null
    };

    Map.set(_dvectors, nhash, pid, dvector);
    _architects.add_vector(caller, pid);
    _indexer_left.register_vector(pid, dvector);
    _indexer_right.register_vector(pid, dvector);
    _history.add([], #create_vector({ vid = pid; owner = caller; source_ledger = req.source.ledger; destination_ledger = req.destination.ledger; }));

    #ok pid;
  };

  public query({caller}) func get_vector(pid : DVectorId) : async ?DVectorShared {
    let ?vec = Map.get(_dvectors, nhash, pid) else return null;
    if (vec.owner == caller) T.DVector.toShared(?vec)
    else T.DVector.toSharedNotOwner(?vec);
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
    let total = _history_cls.end();
    let real_len = Nat.min(length, if (start > total) 0 else total - start);

    let entries = Array.tabulate<(?T.History.TxId, ?T.History.Tx)>(
      real_len,
      func(i) {
        let id = start + i;
        let tx = _history_cls.getOpt(id);
        (?id, tx);
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

    let history_cls = SWB.SlidingWindowBuffer<T.History.TxId>(vector.history);
    let total = history_cls.end();

    let real_len = Nat.min(length, if (start >= total) 0 else total - start); 

    let entries = Array.tabulate<(?T.History.TxId, ?T.History.Tx)>(
      real_len,
      func(i) {
        let lid = start + i;
        let ?id = history_cls.getOpt(lid) else return (null, null);
        let tx = _history_cls.getOpt(id);
        (?id, tx);
      },
    );

    #ok {
      total;
      entries;
    };
  };

  public type WithdrawRequest = {
    id : T.DVectorId;
    to : Ledger.Account;
    amount : Nat;
    location : T.VLocation;
  };

  public query func validate_withdraw_vector(req: WithdrawRequest): async T.SNSValidationResult {
    if (not T.is_valid_account(req.to)) return #Err("To address is not valid");
    let ?vector = Map.get(_dvectors, nhash, req.id) else return #Err("vector not found");
    if (vector.unconfirmed_transactions.size() > 10) return #Err("too many unconfirmed transactions");

    #Ok(debug_show(req));
  };

  public shared ({ caller }) func withdraw_vector({
    id : T.DVectorId;
    to : Ledger.Account;
    amount : Nat;
    location : T.VLocation;
  } : WithdrawRequest) : async R<Nat64, Text> {

    if (not T.is_valid_account(to)) return #err("To address is not valid");
    let ?vector = Map.get(_dvectors, nhash, id) else return #err("vector not found");
    if (caller != vector.owner) return #err("caller is not the owner");
    if (vector.unconfirmed_transactions.size() > 10) return #err("too many unconfirmed transactions");
    switch (location) {
      case (#source) {
          if (amount <= vector.source.ledger_fee * 100) return #err("amount is too low");
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
          if (amount <= vector.destination.ledger_fee * 100) return #err("amount is too low");
      };
    };

    #ok(_matching.make_withdraw_transaction(id, vector, amount, to, location));
  };

  public query func show_log() : async [?Text] {
    _errlog.get();
  };


  type SnapshotResponse = {
    monitor: [Monitor.Metric];
    indexed_left: Nat;
    indexed_right: Nat;
  };

  public query func monitor_snapshot() : async SnapshotResponse {
    {
      monitor =_monitor.snapshot();
      indexed_left = if (LEFT_ledger == ICP_ledger_id) _indexer_left_mem.last_indexed_tx else _indexer_left_mem_icrc.last_indexed_tx;
      indexed_right = _indexer_right_mem.last_indexed_tx;
    }
  };

    public query func icrc3_get_blocks(args: Rechain.GetBlocksArgs): async Rechain.GetBlocksResult {
        return rechain.get_blocks(args);
    };

    public query func icrc3_get_archives(args: Rechain.GetArchivesArgs): async Rechain.GetArchivesResult {
        return rechain.get_archives(args);
    };

    public query func icrc3_supported_block_types(): async [Rechain.BlockType] {
        return rechain.icrc3_supported_block_types();
    };

    public query func rechain_stats() : async Rechain.Stats {
        rechain.stats();
    };

    public shared({caller}) func init(): async () {
        assert(Principal.isController(caller));
        chain_mem.canister := ?Principal.fromActor(this);
    };

    public query func icrc_45_list_pairs() : async PairMarketData.ListPairsResponse {
        [{data= Principal.fromActor(this); id=_my_pair_id}]
    };

    public query func icrc_45_get_pairs(req: PairMarketData.PairRequest) : async PairMarketData.PairResponse {
      let res = Vector.new<PairMarketData.PairData>();
      for (pair_id in Iter.fromArray(req.pairs)) {
        if (pair_id == _my_pair_id) {
          Vector.add(res, _market_data.getPairData(req.depth));
        } else {
          return #Err(#NotFound(pair_id));
        }
      };
      #Ok(Vector.toArray(res));
    };

    public query func canister_info() : async Info.CanisterInfo {
        _info.info();
    };


    public shared func deposit_cycles() : async () {
        let amount = ExperimentalCycles.available();
        let accepted = ExperimentalCycles.accept<system>(amount);
        assert (accepted == amount);
    };

};
