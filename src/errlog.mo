
import SWB "mo:swbstable/Stable";
import T "./types";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";

module {

    public class ErrLog({
        mem : SWB.SlidingWindowBuffer<Text>
    }) { 

        public func add(e: Text) {
     
            ignore mem.add(Nat32.toText(T.now()) # " : " # e);
            if (mem.len() > 1000) { // Max 1000
                mem.delete(1); // Delete 1 element from the beginning
            };

        };

        public func get() : [?Text] {
          let start = mem.start();

          Array.tabulate(
                mem.len(),
                func(i : Nat) : ?Text {
                    mem.getOpt(start + i);
                },
            );
        };

    }
}