import T "./types";
import Vector "mo:vector";
import SWB "mo:swbstable/Stable";

module {

    public class ErrLog({
        mem : SWB.SlidingWindowBuffer<Text>
    }) { 

        public func add(e: Text) {
     
            ignore mem.add(e);
            if (mem.len() > 1000) { // Max 1000
                mem.delete(1); // Delete 1 element from the beginning
            };
           

        };

    }
}