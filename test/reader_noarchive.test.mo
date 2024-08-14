import Map "mo:map/Map";
import Principal "mo:base/Principal";
import ICRC "./ledger/icrc";
import U "./ledger/utils";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import SWB "mo:swbstable";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
//import Deduplication "./reducers/deduplication";
import Deduplication "./ledger/reducers/deduplication";
import T "./ledger/types";
import Trechain "../src/types";
//import Balances "reducers/balances";
import Balances "./ledger/reducers/balances";
import Sha256 "mo:sha2/Sha256";
//ILDE
import noarchive "../src/noarchive";
import Vec "mo:vector";
import Nat64 "mo:base/Nat64";
import RepIndy "mo:rep-indy-hash";
import Timer "mo:base/Timer";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

actor Self {//KeyValue(phonebook : Nat){

    // -- Ledger configuration
    let config : T.Config = {
        var TX_WINDOW  = 86400_000_000_000;  // 24 hours in nanoseconds
        var PERMITTED_DRIFT = 60_000_000_000;
        var FEE = 0;//1_000; ILDE: I make it 0 to simplify testing
        var MINTING_ACCOUNT = {
            owner = Principal.fromText("aaaaa-aa");
            subaccount = null;
            }
    };

    // -- Reducer : Balances
    stable let balances_mem = Balances.Mem();
    let balances = Balances.Balances({
        config;
        mem = balances_mem;
    });

    // -- Reducer : Deduplication

    stable let dedup_mem = Deduplication.Mem();
    let dedup = Deduplication.Deduplication({
        config;
        mem = dedup_mem;
    });

    // -- Chain

    stable let chain_mem = noarchive.Mem();


    // func encodeBlock(b: T.Action) : [Trechain.ValueMap] {

    //     let created_at_time: Nat64 = switch (b.created_at_time) {
    //         case null 0;
    //         case (?Nat) Nat;
    //     };
    //     let memo: Blob = switch (b.memo) {
    //         case null "0" : Blob;
    //         case (?Blob) Blob;
    //     };
    //     let fee: Nat = switch (b.fee) {
    //         case null 0;
    //         case (?Nat) Nat;
    //     };
    //     [
    //         ("ts", #Nat(Nat64.toNat(b.ts))),

    //         ("btype", #Text(switch (b.payload) {
    //                 case (#burn(_)) "1burn";
    //                 case (#transfer(_)) "1xfer";
    //                 case (#mint(_)) "1mint";
    //                 case (#transfer_from(_)) "2xfer";
    //             })),
    //         ("tx", #Map([
    //             ("created_at_time", #Nat(Nat64.toNat(created_at_time))),
    //             ("memo", #Blob(memo)),
    //             ("caller", #Blob(Principal.toBlob(b.caller))),
    //             ("fee", #Nat(fee)),
    //             ("payload", #Map(switch (b.payload) {
    //                 case (#burn(data)) {
    //                     let inner_trx = Vec.new<(Text, rechain.Value)>();
    //                     let amt: Nat = data.amt;
    //                     Vec.add(inner_trx, ("amt", #Nat(amt)));
    //                     let trx_from = Vec.new<rechain.Value>();
    //                     for(thisItem in data.from.vals()){
    //                         Vec.add(trx_from,#Blob(thisItem));
    //                     };
    //                     let trx_from_array = Vec.toArray(trx_from);
    //                     Vec.add(inner_trx, ("from", #Array(trx_from_array)));  
    //                     let inner_trx_array = Vec.toArray(inner_trx); 
    //                     inner_trx_array;        
    //                 };
    //                 case (#transfer(data)) {
    //                     let inner_trx = Vec.new<(Text, rechain.Value)>();
    //                     let amt: Nat = data.amt;
    //                     Vec.add(inner_trx, ("amt", #Nat(amt)));
    //                     let trx_from = Vec.new<rechain.Value>();
    //                     for(thisItem in data.from.vals()){
    //                         Vec.add(trx_from,#Blob(thisItem));
    //                     };
    //                     let trx_from_array = Vec.toArray(trx_from);
    //                     Vec.add(inner_trx, ("from", #Array(trx_from_array)));  
    //                     let trx_to = Vec.new<rechain.Value>();
    //                     for(thisItem in data.to.vals()){
    //                         Vec.add(trx_to,#Blob(thisItem));
    //                     };
    //                     let trx_to_array = Vec.toArray(trx_to);
    //                     Vec.add(inner_trx, ("to", #Array(trx_to_array))); 
    //                     let inner_trx_array = Vec.toArray(inner_trx);
    //                     inner_trx_array;
    //                 };
    //                 case (#mint(data)) {
    //                     let inner_trx = Vec.new<(Text, rechain.Value)>();
    //                     let amt: Nat = data.amt;
    //                     Vec.add(inner_trx, ("amt", #Nat(amt)));
    //                     let trx_to = Vec.new<rechain.Value>();
    //                     for(thisItem in data.to.vals()){
    //                         Vec.add(trx_to,#Blob(thisItem));
    //                     };
    //                     let trx_to_array = Vec.toArray(trx_to);
    //                     Vec.add(inner_trx, ("to", #Array(trx_to_array)));  
    //                     let inner_trx_array = Vec.toArray(inner_trx);
    //                     inner_trx_array; 
    //                 };
    //                 case (#transfer_from(data)) {
    //                     let inner_trx = Vec.new<(Text, rechain.Value)>();
    //                     let amt: Nat = data.amt;
    //                     Vec.add(inner_trx, ("amt", #Nat(amt)));
    //                     let trx_from = Vec.new<rechain.Value>();
    //                     for(thisItem in data.from.vals()){
    //                         Vec.add(trx_from,#Blob(thisItem));
    //                     };
    //                     let trx_from_array = Vec.toArray(trx_from);
    //                     Vec.add(inner_trx, ("from", #Array(trx_from_array)));  
    //                     let trx_to = Vec.new<rechain.Value>();
    //                     for(thisItem in data.to.vals()){
    //                         Vec.add(trx_to,#Blob(thisItem));
    //                     };
    //                     let trx_to_array = Vec.toArray(trx_to);
    //                     Vec.add(inner_trx, ("to", #Array(trx_to_array))); 
    //                     let inner_trx_array = Vec.toArray(inner_trx);
    //                     inner_trx_array; 
    //                 };
    //             },))
    //         ])),
    //     ];
    // };

    public query func compute_hash(auxm1: Trechain.Value) : async ?Blob {
        let ret = ?Blob.fromArray(RepIndy.hash_val(auxm1));
        return ret;
    };

    //<-----IMHERE
    var chain = noarchive.RechainNoArchive<T.Action, T.ActionError>({ 
        //settings = ?{rechain.DEFAULT_SETTINGS with supportedBlocks = [];maxActiveRecords = 60; settleToRecords = 30; maxRecordsInArchiveInstance = 100;};
        mem = chain_mem;
        //encodeBlock = encodeBlock;
        reducers = [balances.reducer];//, dedup.reducer];//, balancesIlde.reducer];  
    });

    // public shared(msg) func check_archives_balance(): async () {
    //     return await chain.check_archives_balance();
    // };

    // public shared(msg) func set_ledger_canister(): async () {
    //     chain_mem.canister := ?Principal.fromActor(Self);
    //     //chain.set_ledger_canister(Principal.fromActor(this));
    // };

    // public shared(msg) func add_record(x: T.Action): async (DispatchResult) {
    //     //return icrc3().add_record<system>(x, null);

    //     let ret = chain.dispatch(x);  //handle error
    //     //add block to ledger

    //     return ret;


    // };

    public query func icrc1_balance_of(acc: ICRC.Account) : async Nat {
        balances.get(acc)
    };
 
    public type DispatchResult = {#Ok : Nat;  #Err: T.ActionError };

    public func dispatch(actions: [T.Action]): async [DispatchResult] {
        Array.map(actions, func(x: T.Action): DispatchResult = chain.dispatch(x));
    };

};