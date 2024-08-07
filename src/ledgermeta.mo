import Timer "mo:base/Timer";
import Map "mo:map/Map";
import T "./types";

module {
    let phash = Map.phash;

    public class LedgerMeta({ledgers: [Principal]}) {

        let _meta = Map.new<Principal, T.LedgerMeta>();

        var fetchidx = 0;

        public func fetch<system>() : async () {
            try {
                let m = await T.ledgerMeta(ledgers[fetchidx]);
                Map.set<Principal, T.LedgerMeta>(_meta, phash, ledgers[fetchidx], m);
                fetchidx += 1;
                if (fetchidx < ledgers.size()) {
                    ignore Timer.setTimer<system>(#seconds 0, fetch);
                }
            } catch (_) {
                // retry
                ignore Timer.setTimer<system>(#seconds 2, fetch);
            }
        };

        public func get(ledger: Principal) : ?T.LedgerMeta {
             Map.get<Principal, T.LedgerMeta>(_meta, phash, ledger);
        };

        public func start_timer<system>() {
            ignore Timer.setTimer<system>(#seconds 2, fetch);
        };
    }
}