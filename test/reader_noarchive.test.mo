import Principal "mo:base/Principal";
import ICRC "./ledger/icrc";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Deduplication "./ledger/reducers/deduplication";
import T "./ledger/types";
import Trechain "../src/types";
import Balances "./ledger/reducers/balances";
import noarchive "../src/noarchive";
import RepIndy "mo:rep-indy-hash";

actor Self {

    let config : T.Config = {
        var TX_WINDOW  = 86400_000_000_000; 
        var PERMITTED_DRIFT = 60_000_000_000;
        var FEE = 0;
        var MINTING_ACCOUNT = {
            owner = Principal.fromText("aaaaa-aa");
            subaccount = null;
            }
    };

    stable let balances_mem = Balances.Mem();
    let balances = Balances.Balances({
        config;
        mem = balances_mem;
    });

    stable let dedup_mem = Deduplication.Mem();
    let dedup = Deduplication.Deduplication({
        config;
        mem = dedup_mem;
    });

    stable let chain_mem = noarchive.Mem();

    public query func compute_hash(auxm1: Trechain.Value) : async ?Blob {
        let ret = ?Blob.fromArray(RepIndy.hash_val(auxm1));
        return ret;
    };

    var chain = noarchive.RechainNoArchive<T.Action, T.ActionError>({ 
        mem = chain_mem;
        reducers = [balances.reducer];  
    });

    public shared(msg) func add_record(x: T.Action): async (DispatchResult) {
        let ret = chain.dispatch(x);
        return ret;
    };

    public query func icrc1_balance_of(acc: ICRC.Account) : async Nat {
        balances.get(acc)
    };
 
    public type DispatchResult = {#Ok : Nat;  #Err: T.ActionError };

};