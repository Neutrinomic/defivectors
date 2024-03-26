import M "./mock_aggregator_if";

actor {

    public query func get_latest_extended() : async [M.LatestExtendedToken] {

        return [
            {
                id = 1; // matters
                last = ?{
                    fee = 0;
                    dissolving_30d = 0;
                    circulating_supply = 19658368;
                    other_treasuries = [];
                    total_locked = 0;
                    dissolving_1d = 0;
                    dissolving_1y = 0;
                    total_supply = 21000000;
                    treasury = 0;
                };
                config = {
                    decimals = 0;
                    deleted = false;
                    locking = #none;
                    name = "Bitcoin";
                    ledger = #none;
                    details = [];
                    symbol = "BTC"
                };
                rates = [
                    {
                        to_token= 0; // matters
                        rate= 67028.989359261; // matters
                        volume= 8853473213.149145;
                        depth50= 0;
                        depth2= 0;
                        depth8= 0;
                        symbol= "BTC/USD";
                    }
                ];
            },
            {
                id = 30; // matters
                last = ?{
                    fee = 0;
                    dissolving_30d = 0;
                    circulating_supply = 19658368;
                    other_treasuries = [];
                    total_locked = 0;
                    dissolving_1d = 0;
                    dissolving_1y = 0;
                    total_supply = 21000000;
                    treasury = 0;
                };
                config = {
                    decimals = 8;
                    deleted = false;
                    locking = #none;
                    name = "Neutrinite";
                    ledger = #none;
                    details = [];
                    symbol = "NTN"
                };
                rates = [
                    {
                        to_token= 0; // matters
                        rate= 6.465749483788241; // matters
                        volume= 3131.255683565812;
                        depth50= 0;
                        depth2= 0;
                        depth8= 0;
                        symbol= "NTN/USD";
                    }
                ];
            },
            {
                id = 3; // matters
                last = ?{
                    fee = 0;
                    dissolving_30d = 0;
                    circulating_supply = 19658368;
                    other_treasuries = [];
                    total_locked = 0;
                    dissolving_1d = 0;
                    dissolving_1y = 0;
                    total_supply = 21000000;
                    treasury = 0;
                };
                config = {
                    decimals = 8;
                    deleted = false;
                    locking = #none;
                    name = "Internet Computer";
                    ledger = #none;
                    details = [];
                    symbol = "ICP"
                };
                rates = [
                    {
                        to_token = 0; // matters
                        rate= 17.378262156; // matters
                        volume= 305821096.07989615;
                        depth50= 0;
                        depth2= 0;
                        depth8= 0;
                        symbol= "ICP/USD";
                    }
                ];
            }
        ]
 

    }

}