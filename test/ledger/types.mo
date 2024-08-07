import ICRC "./icrc";

import SW "mo:stable-write-only"; // ILDE: I have to add mops.toml

module {
    public type Config = {
        var TX_WINDOW : Nat64;
        var PERMITTED_DRIFT : Nat64;
        var FEE : Nat;
        var MINTING_ACCOUNT : ICRC.Account;
    };
    public type ActionError = ICRC.TransferError; // can add more error types with 'or'

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
        created_at_time: ?Nat64; //ILDE: I have added after the discussion with V
        memo: ?Blob; //ILDE: I have added after the discussion with V
        caller: Principal;  //ILDE: I have added after the discussion with V 
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


}