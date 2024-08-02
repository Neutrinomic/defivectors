import Time "mo:base/Time";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Prim "mo:⛔";


module {

    public type CanisterInfo = {
      last_upgrade : Int;
      cycles: Nat;
      version: Nat64;
    };

    public class Info() {
        let last_upgrade = Time.now();

        public func info() : CanisterInfo {
            let cycles = ExperimentalCycles.balance();
            {
                last_upgrade;
                cycles;
                version = Prim.canisterVersion();
            }
        }
    };

   

}