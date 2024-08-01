import T "./types";
import SWB "mo:swbstable/Stable";

module {

    public class History({
        mem : SWB.SlidingWindowBuffer<T.History.Tx>;
    }) {

        public func add(vectors : [T.DVector], kind : T.History.TxKind) {
            let tx : T.History.Tx = {
                timestamp = T.now();
                kind;
            };

            // Add to global history
            let tx_id = mem.add(tx);
            if (mem.len() > 200000) {
                // Max 200,000 total history
                mem.delete(1); // Delete 1 element from the beginning
            };

            // Add to temporary local vector history
            for (v in vectors.vals()) {
                let history_cls = SWB.SlidingWindowBuffer<T.History.TxId>(v.history);
                ignore history_cls.add(tx_id);
                if (history_cls.len() > 300) {
                    // MAX 300 vector local history
                    history_cls.delete(1); // Delete 1 element from the beginning
                };
            };


        };

    };

    
};
