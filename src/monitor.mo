import SWB "mo:swb";
import T "./types";
import Prim "mo:⛔";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

    public type Metric = (T.Timestamp, MetricKey, MetricVal);

    public let PREPARE_VECTORS:MetricKey = 0;
    public let SENDER:MetricKey = 1;
    public let SETTLE_VECTORS:MetricKey = 2;
    public let INDEXER_LEFT:MetricKey = 3;
    public let INDEXER_RIGHT:MetricKey = 4;

    public type MetricKey = Nat8;
    public type MetricVal = Nat64;

    public class Monitor() {

        let buf = SWB.SlidingWindowBuffer<Metric>();
        public func measure(metric_key:MetricKey, comp: () -> () ) : () {
            let start = Prim.performanceCounter(0);
            comp();
            let end = Prim.performanceCounter(0);
            add(metric_key, end - start);
        };

        public func add(k:MetricKey, m:MetricVal) : () {
            let idx = buf.add((T.now(), k, m));
            if ((1+idx) % 300 == 0) { // every 300 elements
                buf.delete( buf.len() - 100 ) // delete all but the last 100
            };
        };

        public func snapshot() : [Metric] {
            let start = buf.start();
            Array.tabulate<Metric>(buf.len(), func (i:Nat) {
                let ?x = buf.getOpt(start + i) else Debug.trap("memory corruption");
                x
            });
        };
    };
}