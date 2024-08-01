import Vector "mo:vector";
import DVector "./main";
import Principal "mo:base/Principal";
import T "./types";
import Debug "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Timer "mo:base/Timer";

actor class Root(init_args : ?T.RootInitArg) = this {

    stable let _init = switch(init_args) { case (?a) { a }; case(null) { Debug.trap("No args provided") } };

    let DVECTOR_CYCLES = 10_000_000_000_000;
    let DVECTOR_ADDITIONAL_CONTROLLERS : [Principal] = [];

    public type Pair = {
        init_args: T.ProdInitArg;
        canister_id: Principal;
    };

    stable let _pairs = Vector.new<Pair>();

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

    private func new_pair_canister<system>(initArg : T.InitArg) : async (DVector.Swap) {
      
      let this_canister = Principal.fromActor(this);

      if (ExperimentalCycles.balance() > DVECTOR_CYCLES * 2) {
        ExperimentalCycles.add<system>(DVECTOR_CYCLES);
      } else {
        Debug.trap("Not enough cycles" # debug_show (ExperimentalCycles.balance()));
      };

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
        return (await DVectorMgr(initArg));
      } catch (err) {
        Debug.trap("Error creating archive canister " # Error.message(err));
      };

    };

    private func upgrade_pair_canisters<system>() : async () {

      for (dvec in Vector.vals(_pairs)) {
        let myActor = actor (Principal.toText(dvec.canister_id)) : DVector.Swap;
        let full_args : T.InitArg = { dvec.init_args with DEFI_AGGREGATOR = _init.DEFI_AGGREGATOR; ICP_ledger_id = _init.ICP_ledger_id; NTN_ledger_id = _init.NTN_ledger_id};

        let DVectorMgr = (system DVector.Swap)(#upgrade myActor);
        ignore await DVectorMgr(full_args);
      };
    };

    // Autoupgrade every time this canister gets upgraded
    ignore Timer.setTimer<system>(#seconds 1, func () : async () {
        await upgrade_pair_canisters<system>();
    });

}