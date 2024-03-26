import DA "./services/defiaggregator";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Map "mo:map/Map";
import Principal "mo:base/Principal";

module {
    type Whitelisted = [(Nat, Principal)];
    let phash = Map.phash;

    public class Rates({whitelisted: Whitelisted; DEFI_AGGREGATOR: Principal}) {
        
        let da = actor(Principal.toText(DEFI_AGGREGATOR)) : DA.Self; //"u45jl-liaaa-aaaam-abppa-cai"
        let _rates = Map.new<Principal, Float>();

        private func update() : async () {

            let latest = await da.get_latest_extended();

            label search for ((id, ledger) in whitelisted.vals()) {
                let ?p = Array.find(latest, func (x : DA.LatestExtendedToken) : Bool {
                    (x.id == id)
                }) else continue search;

                let ?to_usd = Array.find(p.rates, func (x: DA.LatestExtendedRate) : Bool {
                    x.to_token == 0 // usd id
                }) else continue search;

                ignore Map.put<Principal, Float>(_rates, phash, ledger, to_usd.rate);
            }

        };
        public func get_whitelisted() : Whitelisted {
            whitelisted;
        };
        
        public func get_rate(ledger: Principal) : ?Float {
            Map.get<Principal, Float>(_rates, phash, ledger);
        };


        public func start_timer() {
            ignore Timer.setTimer(#seconds 0, update);
            ignore Timer.recurringTimer(#seconds 60, update);
        }
    }
}