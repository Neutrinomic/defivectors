import T "./types";
import Vector "mo:vector";

module {

    public class History({
        mem : Vector.Vector<T.History.Tx>
    }) { // Todo archive older transactions

        public func add(vectors: [T.DVector], kind: T.History.TxKind) {
            let tx : T.History.Tx = {
                timestamp = T.now();
                kind
           };
           let tx_id = Vector.size(mem);
           Vector.add(mem, tx);
           for (v in vectors.vals()) {
               Vector.add(v.history, tx_id);
           }

        };

    }
}