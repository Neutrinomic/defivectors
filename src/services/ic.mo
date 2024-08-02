// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type canister_id = Principal;
  public type canister_settings = {
    freezing_threshold : ?Nat;
    controllers : ?[Principal];
    memory_allocation : ?Nat;
    compute_allocation : ?Nat;
  };
  public type definite_canister_settings = {
    freezing_threshold : Nat;
    controllers : [Principal];
    memory_allocation : Nat;
    compute_allocation : Nat;
  };
  public type http_header = { value : Text; name : Text };
  public type http_request_error = {
    #dns_error;
    #no_consensus;
    #transform_error;
    #unreachable;
    #bad_tls;
    #conn_timeout;
    #invalid_url;
    #timeout;
  };
  public type http_response = {
    status : Nat;
    body : Blob;
    headers : [http_header];
  };
  public type user_id = Principal;
  public type wasm_module = Blob;
  public type CanisterStatus =  {
        status : { #stopped; #stopping; #running };
        memory_size : Nat;
        cycles : Nat;
        settings : definite_canister_settings;
        module_hash : ?Blob;
      };
      
  public type Self = actor {
    canister_status : shared { canister_id : canister_id } -> async CanisterStatus;
    create_canister : shared { settings : ?canister_settings } -> async {
        canister_id : canister_id;
      };
    delete_canister : shared { canister_id : canister_id } -> async ();
    deposit_cycles : shared { canister_id : canister_id } -> async ();
    http_request : shared {
        url : Text;
        method : { #get };
        body : ?Blob;
        transform : ?{
          #function : shared query http_response -> async http_response;
        };
        headers : [http_header];
      } -> async { #Ok : http_response; #Err : ?http_request_error };
    install_code : shared {
        arg : Blob;
        wasm_module : wasm_module;
        mode : { #reinstall; #upgrade; #install };
        canister_id : canister_id;
      } -> async ();
    provisional_create_canister_with_cycles : shared {
        settings : ?canister_settings;
        amount : ?Nat;
      } -> async { canister_id : canister_id };
    provisional_top_up_canister : shared {
        canister_id : canister_id;
        amount : Nat;
      } -> async ();
    raw_rand : shared () -> async Blob;
    start_canister : shared { canister_id : canister_id } -> async ();
    stop_canister : shared { canister_id : canister_id } -> async ();
    uninstall_code : shared { canister_id : canister_id } -> async ();
    update_settings : shared {
        canister_id : Principal;
        settings : canister_settings;
      } -> async ();
  }
}
