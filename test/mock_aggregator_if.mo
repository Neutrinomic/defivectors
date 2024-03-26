// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type AdminCommand = {
    #token_collect : TokenId;
    #pair_add : PairConfig;
    #pair_del : PairId;
    #pair_set : (PairId, PairConfig);
    #token_add : TokenConfig;
    #token_del : TokenId;
    #token_set : (TokenId, TokenConfig);
  };
  public type Asset = { class_ : AssetClass; symbol : Text };
  public type AssetClass = { #Cryptocurrency; #FiatCurrency };
  public type DepthAsk50 = [Float];
  public type DepthBid50 = [Float];
  public type ErrorCode = {
    #canister_error;
    #call_error : { err_code : Nat32 };
    #system_transient;
    #future : Nat32;
    #canister_reject;
    #destination_invalid;
    #system_fatal;
  };
  public type ErrorLine = (Time, Text, ErrorCode, Text);
  public type Frame = { #t1d; #t1h; #t5m };
  public type GetError = { #invalid_frame };
  public type High = Float;
  public type LastAsk = Float;
  public type LastBid = Float;
  public type LatestExtendedRate = {
    to_token : TokenId;
    rate : Float;
    volume : Float;
    depth50 : Float;
    depth2 : Float;
    depth8 : Float;
    symbol : Text;
  };
  public type LatestExtendedToken = {
    id : TokenId;
    last : ?LatestExtendedTokenTickItem;
    config : TokenConfig;
    rates : [LatestExtendedRate];
  };
  public type LatestExtendedTokenTickItem = {
    fee : Nat;
    dissolving_30d : Nat;
    circulating_supply : Nat;
    other_treasuries : [(TokenId, Nat)];
    total_locked : Nat;
    dissolving_1d : Nat;
    dissolving_1y : Nat;
    total_supply : Nat;
    treasury : Nat;
  };
  public type LatestTokenRow = ((TokenId, TokenId), Text, Float);
  public type LatestWalletTokenTicks = {
    t6h : [Float];
    to_id : TokenId;
    from_id : TokenId;
  };
  public type LatestWalletTokens = {
    ticks : [LatestWalletTokenTicks];
    latest : [LatestExtendedToken];
  };
  public type LockingTick = {
    not_dissolving : [Nat];
    other_treasuries : [(TokenId, Nat)];
    total_locked : Nat;
    dissolving : [Nat];
    treasury : Nat;
  };
  public type Low = Float;
  public type NodeInfoShared = {
    bad : Nat;
    principal : Principal;
    good : Nat;
    last : Time;
    name : Text;
  };
  public type OraclePushError = { #not_in_validator_set; #too_early };
  public type PairConfig = {
    deleted : Bool;
    tokens : (TokenId, TokenId);
    config : {
      #xrc : { quote_asset : Asset; base_asset : Asset };
      #oracle : { id : Text };
      #icpswap : { canister : Principal };
      #sonic : { id : Text };
      #icdex : { canister : Principal };
    };
  };
  public type PairId = Nat;
  public type Result = { #ok : Time; #err : OraclePushError };
  public type Result_1 = {
    #ok : {
      first : Time;
      data : [TokenTickShared];
      last : Time;
      updated : Time;
    };
    #err : GetError;
  };
  public type Result_2 = {
    #ok : { first : Time; data : [TickShared]; last : Time; updated : Time };
    #err : GetError;
  };
  public type Result_3 = { #ok; #err : Text };
  public type SnsConfig = {
    root : Principal;
    swap : Principal;
    ledger : Principal;
    other_treasuries : [
      { token_id : TokenId; owner : Principal; subaccount : Blob }
    ];
    index : Principal;
    governance : Principal;
    treasury_subaccount : Blob;
  };
  public type TickItem = (
    High,
    Low,
    LastBid,
    LastAsk,
    Volume24,
    DepthBid50,
    DepthAsk50,
  );
  public type TickShared = [?TickItem];
  public type Time = Int;
  public type TokenConfig = {
    decimals : Nat;
    deleted : Bool;
    locking : TokenLocking;
    name : Text;
    ledger : {
      #none;
      #icrc1 : { ledger : Principal };
      #dip20 : { ledger : Principal };
    };
    details : [TokenDetail];
    symbol : Text;
  };
  public type TokenDetail = {
    #link : { href : Text; name : Text };
    #sns_sale : { end : Time; sold_tokens : Nat; price_usd : Float };
  };
  public type TokenId = Nat;
  public type TokenLocking = { #ogy; #sns : SnsConfig; #none };
  public type TokenTickItem = {
    fee : Nat;
    locking : ?LockingTick;
    circulating_supply : Nat;
    total_supply : Nat;
  };
  public type TokenTickShared = [?TokenTickItem];
  public type Volume24 = Float;
  public type Self = actor {
    admin : shared [AdminCommand] -> async ();
    controller_export_pair : shared (Frame, Time, Nat, Nat) -> async [
        ?TickItem
      ];
    controller_import_pair : shared (
        Frame,
        Time,
        Nat,
        [?TickItem],
        { #add; #overwrite },
      ) -> async ();
    controller_oracle_add : shared (Text, Principal) -> async Result_3;
    controller_oracle_rem : shared Principal -> async Result_3;
    get_config : shared query () -> async {
        tokens : [TokenConfig];
        pairs : [PairConfig];
      };
    get_latest : shared query () -> async [LatestTokenRow];
    get_latest_extended : shared query () -> async [LatestExtendedToken];
    get_latest_wallet_tokens : shared query () -> async LatestWalletTokens;
    get_pairs : shared query (Frame, [Nat], ?Time, ?Time) -> async Result_2;
    get_tokens : shared query ([Nat], ?Time, ?Time) -> async Result_1;
    log_show : shared query () -> async [?ErrorLine];
    oracle_push : shared { data : [(Text, Float)] } -> async Result;
    oracles_get : shared query () -> async [NodeInfoShared];
  }
}