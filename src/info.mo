import Time "mo:base/Time";
import ExperimentalCycles "mo:base/ExperimentalCycles";

module {

    public type CanisterInfo = {
      last_upgrade : Int;
      cycles: Nat;
    };

    public class Info() {
        let last_upgrade = Time.now();

        public func info() : CanisterInfo {
            let cycles = ExperimentalCycles.balance();
            {
                last_upgrade;
                cycles;
            }
        }
    };

   

}