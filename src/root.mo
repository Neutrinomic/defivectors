import Vector "mo:vector";
import DVector "./main";
import Principal "mo:base/Principal";
import T "./types";
import Debug "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Info "./info";
import SWB "mo:swbstable/Stable";
import ErrLog "./errlog";
import IC "./services/ic";
import Nat "mo:base/Nat";

actor class Root(init_args : ?T.RootInitArg) = this {

    stable let _init = switch(init_args) { case (?a) { a }; case(null) { Debug.trap("No args provided") } };

    let DVECTOR_CYCLES = 10_000_000_000_000;
    let DVECTOR_ADDITIONAL_CONTROLLERS : [Principal] = [];

    public type Pair = {
        init_args: T.ProdInitArg;
        canister_id: Principal;
    };

    stable let _pairs = Vector.new<Pair>();

    let _info = Info.Info();

    stable let _eventlog_mem = SWB.SlidingWindowBufferNewMem<Text>();
    let _eventlog_cls = SWB.SlidingWindowBuffer<Text>(_eventlog_mem);
    let _eventlog = ErrLog.ErrLog({
      mem = _eventlog_cls;
    });

    let ic = actor("aaaaa-aa"): IC.Self;

    public shared({caller}) func add_pair(iargs: T.ProdInitArg) : async () {
        assert(Principal.isController(caller));
        
        let full_args : T.InitArg = { iargs with DEFI_AGGREGATOR = _init.DEFI_AGGREGATOR; ICP_ledger_id = _init.ICP_ledger_id; NTN_ledger_id = _init.NTN_ledger_id};

        let new_actor = await new_pair_canister<system>(full_args);
        
        await new_actor.init();

        let canister_id = Principal.fromActor(new_actor);

        Vector.add(_pairs, {
            init_args = iargs;
            canister_id;
        });
    };

    public query func validate_add_pair(iargs: T.ProdInitArg): async T.SNSValidationResult {

      let msg:Text = "
        Adding new pair to DEVEFI:
        LEFT_ledger: " # Principal.toText(iargs.LEFT_ledger) # "
        RIGHT_ledger: " # Principal.toText(iargs.RIGHT_ledger) # "
        LEFT_aggr_id:  " # Nat.toText(iargs.LEFT_aggr_id) # "
        RIGHT_aggr_id: " # Nat.toText(iargs.RIGHT_aggr_id) # ";
      ";

      #Ok(msg);
    };
    

    public query func list_pairs() : async [Pair] {
        Vector.toArray(_pairs);
    };

    private func new_pair_canister<system>(initArg : T.InitArg) : async (DVector.Swap) {
      
      let this_canister = Principal.fromActor(this);

      if (ExperimentalCycles.balance() > DVECTOR_CYCLES * 2) {
        ExperimentalCycles.add<system>(DVECTOR_CYCLES);
      } else {
        _eventlog.add("ERR : Not enough cycles" # debug_show (ExperimentalCycles.balance()));

        Debug.trap("Not enough cycles" # debug_show (ExperimentalCycles.balance()));
      };
      _eventlog.add("OK : Creating new pair canister " # debug_show (initArg));

      let DVectorMgr = (system DVector.Swap)(
        #new {
          settings = ?{
            controllers = ?Array.append([this_canister], DVECTOR_ADDITIONAL_CONTROLLERS);
            compute_allocation = null;
            memory_allocation = null;
            freezing_threshold = null;
          };
        }
      );

      try {
        let newactor = (await DVectorMgr(initArg));
        _eventlog.add("OK : Pair canister created " # Principal.toText(Principal.fromActor(newactor)) );
        return newactor;
      } catch (err) {
        _eventlog.add("ERR : Failed creating pair canister " # Error.message(err));
        Debug.trap("Error creating pair canister " # Error.message(err));
      };

    };


    private func upgrade_pair_canisters<system>() : async () {

      for (dvec in Vector.vals(_pairs)) {
        let myActor = actor (Principal.toText(dvec.canister_id)) : DVector.Swap;
        let full_args : T.InitArg = { dvec.init_args with DEFI_AGGREGATOR = _init.DEFI_AGGREGATOR; ICP_ledger_id = _init.ICP_ledger_id; NTN_ledger_id = _init.NTN_ledger_id};

        // 1. Stop canister
        await ic.stop_canister({canister_id = dvec.canister_id});

        // 2. Upgrade
        let DVectorMgr = (system DVector.Swap)(#upgrade myActor);

        try {
          ignore await DVectorMgr(full_args);

          // 3. Start canister
          await ic.start_canister({canister_id = dvec.canister_id});

          _eventlog.add("OK : Successful upgrading of canister " # Principal.toText(dvec.canister_id));
        } catch (err) {
          _eventlog.add("ERR : Failed upgrading canister " # Principal.toText(dvec.canister_id) # " : " # Error.message(err));
        }
      };
    };

    // Autoupgrade every time this canister gets upgraded
    ignore Timer.setTimer<system>(#seconds 1, func () : async () {
        _eventlog.add("OK : Upgrade of pair canisters started");

        await upgrade_pair_canisters<system>();

        _eventlog.add("OK : Upgrade of pair canisters ended");
    });


    public query func canister_info() : async Info.CanisterInfo {
      _info.info();
    };


    public query func show_log() : async [?Text] {
      _eventlog.get();
    };
  }