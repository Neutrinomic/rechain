import ICRC "./icrc";

module {
    public type Config = {
        var TX_WINDOW : Nat64;
        var PERMITTED_DRIFT : Nat64;
        var FEE : Nat;
        var MINTING_ACCOUNT : ICRC.Account;
    };
    public type ActionError = ICRC.TransferError; 

    public type Transfer = {
        to : ICRC.Account;
        fee : ?Nat;
        from : ICRC.Account;
        amount : Nat;
    };
    public type Burn = {
        from : ICRC.Account;
        amount: Nat;
    };
    public type Mint = {
        to : ICRC.Account;
        amount : Nat;
    };

    public type Payload = {
        #transfer: Transfer;
        #burn: Burn;
        #mint: Mint;
    };

    public type Action = {
        ts: Nat64;
        created_at_time: ?Nat64; 
        memo: ?Blob;
        caller: Principal;  
        fee: ?Nat;
        payload : {
            #burn : {
                amt: Nat;
                from: [Blob];
            };
            #transfer : {
                to : [Blob];
                from : [Blob];
                amt : Nat;
            };
            #transfer_from : {
                to : [Blob];
                from : [Blob];
                amt : Nat;
            };
            #mint : {
                to : [Blob];
                amt : Nat;
            };
        };
    };

    public type NoArchiveDispatchReturn = { #Ok : Nat; #Err : ActionError };
    public type NoArchiveInterface = actor {
      add_record : shared (Action) -> async (NoArchiveDispatchReturn);
    };
}