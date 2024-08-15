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
import rechain "../src/lib";
import Vec "mo:vector";
import Nat64 "mo:base/Nat64";
import RepIndy "mo:rep-indy-hash";
import Timer "mo:base/Timer";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

//ILDE reader NEW
import reader "../src/reader";

actor class reader_reader(ledger_pid : Principal, noarchive_pid : Principal) = Self {

    // -- Ledger configuration

    // let config : T.Config = {
    //     var TX_WINDOW  = 86400_000_000_000;  // 24 hours in nanoseconds
    //     var PERMITTED_DRIFT = 60_000_000_000;
    //     var FEE = 0;//1_000; ILDE: I make it 0 to simplify testing
    //     var MINTING_ACCOUNT = {
    //         owner = Principal.fromText("aaaaa-aa");
    //         subaccount = null;
    //         }
    // };

    // // -- Reducer : Balances
    // stable let balances_mem = Balances.Mem();
    // let balances = Balances.Balances({
    //     config;
    //     mem = balances_mem;
    // });

    // // -- Reducer : Deduplication

    // stable let dedup_mem = Deduplication.Mem();
    // let dedup = Deduplication.Deduplication({
    //     config;
    //     mem = dedup_mem;
    // });

    // -- Chain

    //stable let chain_mem = rechain.Mem();

    //stable let reader_mem = reader.Mem();

    //let exnum_ = exnum;

    func decodeBlock(block: ?Trechain.Value) : T.Action {
        // ILDE---> how are the blocks I am generating?
        // #Map([["phash",phash],["ts",ts],["btype",btype],["tx",tx]])

        //Debug.print("Block in decodeBlock:"#debug_show(block));
        //Debug.print("\n---------------\n");
        
        // ?(#Map([("phash", #Blob("\38...")),   // phash is not there in the first block!
        //         ("ts", #Nat(0)), 
        //         ("btype", #Text("1mint")), 
        //         ("tx", #Map([("created_at_time", #Nat(0)), 
        //                      ("memo", #Blob("\30")), 
        //                      ("caller", #Blob("\58...")), 
        //                      ("fee", #Nat(0)), 
        //                      ("payload", #Map([("amt", #Nat(50)), 
        //                                        ("to", #Array([#Blob("\82...")]))]))]))]))
        
        // let from_subaccount_blob = if(p.from.size() > 1) p.from[1] else Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
        // let from_principal_principal = Principal.fromBlob(from_principal_blob);
        // let from_bacc = Principal.toLedgerAccount(from_principal_principal, ?from_subaccount_blob) 
        //    else return #Err(#GenericError({ message = "Invalid From Subaccount"; error_code = 1111 }));
              
        
        
        var phash: Blob = "0";
        var ts: Nat = 0;
        var btype: Text = "";
        var created_at_time: Nat = 0;
        var memo: Blob = "0";
        var caller: Blob = "0";
        var fee: Nat = 0;
        var amt: Nat = 0;
        var to: [Blob] = ["0"];
        var from: [Blob] = ["0"];
        
        switch(block) {
            case (?(#Map(data))) {
                for (x in data.vals()) {
                    switch(x) {
                        case(("phash", #Blob(myblob))) {
                            phash := myblob;
                        };
                        case(("ts", #Nat(mynat))) {
                            ts := mynat;
                        };
                        case(("btype", #Text(mytext))) {
                            btype := mytext;
                        };
                        case(("tx", #Map(mymap))) {
                            Debug.print("tx");
                            Debug.print(debug_show(mymap));
                            for (y in mymap.vals()) {
                                switch(y) {
                                    case(("created_at_time", #Nat(mynat))) {
                                        created_at_time := mynat;
                                    }; 
                                    case(("memo", #Blob(myblob))) {
                                        memo := myblob;
                                    };
                                    case(("caller", #Blob(myblob))) {
                                        caller := myblob;
                                    };
                                    case(("fee", #Nat(mynat))) {
                                        fee := mynat;
                                    }; 
                                    case(("payload", #Map(mymap))) {
                                        for (z in mymap.vals()) {
                                            switch(z) {
                                                case(("amt", #Nat(mynat))) {
                                                    amt := mynat;
                                                };
                                                case(("to", #Array(myarray))) {
                                                    let aux0 = myarray[0];
                                                    let aux1 = if(myarray.size() > 1) myarray[1] else #Blob(Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]));
                                                    switch((aux0,aux1)) {
                                                        case((#Blob(myblob0),#Blob(myblob1))) {
                                                            let aux_array: [Blob] = [myblob0, myblob1];
                                                            to := aux_array;
                                                        };
                                                        case(_){
                                                            Debug.trap("Invalid block cannot be decoded");
                                                        }
                                                    };
                                                };
                                                case(("from", #Array(myarray))) {
                                                    let aux0 = myarray[0];
                                                    let aux1 = if(myarray.size() > 1) myarray[1] else #Blob(Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]));
                                                    switch((aux0,aux1)) {
                                                        case((#Blob(myblob0),#Blob(myblob1))) {
                                                            let aux_array: [Blob] = [myblob0, myblob1];
                                                            from := aux_array;
                                                        };
                                                        case(_){
                                                            Debug.trap("Invalid block cannot be decoded");
                                                        }
                                                    };
                                                };
                                                case(_) {
                                                };
                                            };
                                        };
                                    };
                                    case(_) {
                                    };
                                };
                            };

                        };
                        case(_) {
                            Debug.trap("Invalid block cannot be decoded");
                        }
                    }
                };
            };
            case (_) {
                Debug.trap("Invalid block cannot be decoded");
            };
        };

        // Debug.print("phash");
        // Debug.print(debug_show(phash));
        // Debug.print("ts");
        // Debug.print(debug_show(ts));
        // Debug.print("btype");
        // Debug.print(debug_show(btype));
        // Debug.print("created_at_time");
        // Debug.print(debug_show(created_at_time));
        // Debug.print("memo");
        // Debug.print(debug_show(memo));
        // Debug.print("caller");
        // Debug.print(debug_show(caller));
        // Debug.print("fee");
        // Debug.print(debug_show(fee));
        // Debug.print("to");
        // Debug.print(debug_show(to));
        // Debug.print("from");
        // Debug.print(debug_show(from));

        //BTB let's return a dummy action
        //     public type Action = {
        //     ts: Nat64;
        //     created_at_time: ?Nat64; //ILDE: I have added after the discussion with V
        //     memo: ?Blob; //ILDE: I have added after the discussion with V
        //     caller: Principal;  //ILDE: I have added after the discussion with V 
        //     fee: ?Nat;
        //     payload : {
        //         #burn : {
        //             amt: Nat;
        //             from: [Blob];
        //         };
        //         #transfer : {
        //             to : [Blob];
        //             from : [Blob];
        //             amt : Nat;
        //         };
        //         #transfer_from : {
        //             to : [Blob];
        //             from : [Blob];
        //             amt : Nat;
        //         };
        //         #mint : {
        //             to : [Blob];
        //             amt : Nat;
        //         };
        //     };
        // };

        let return_action: T.Action = {
            ts = Nat64.fromNat(ts);
            created_at_time = ?Nat64.fromNat(created_at_time);
            memo = ?memo;//Blob("0");
            caller = Principal.fromBlob(caller);//(Principal.fromText("kxegj-ch6jp-46fed-oamn7-3t2xz-kquy4-qqicu-hprmr-yo7zi-j6adw-7ae");
            fee = ?fee;
            payload = switch(btype) {
                // case (#burn(_)) "1burn";
                // case (#transfer(_)) "1xfer";
                // case (#mint(_)) "1mint";
                // case (#transfer_from(_)) "2xfer";
                case("1burn"){
                    #burn({
                        amt=amt;
                        from=from;
                      }
                    );
                };
                case("1xfer"){
                    #transfer({
                        amt=amt;
                        from=from;
                        to=to;
                      }
                    );
                };
                case("1mint"){
                    #mint({
                        amt=amt;
                        to=to;
                      }
                    );
                };
                case("2xfer"){
                    #transfer_from({
                        amt=amt;
                        from=from;
                        to=to;
                      }
                    );
                };
                case(_) Debug.trap("Invalid block cannot be decoded");
            };
        };

        //Debug.print(debug_show(return_action));

        return_action;
    };

    func getTimeFromAction(action: T.Action) : Nat64 {
        action.ts;
    };

    func onRead(actions: [T.Action]): async () {
        Debug.print("onRead:");
        Debug.print("actions.size:"#debug_show(actions.size()));
        for(action in actions.vals()) {
            let err = await noarchive.add_record(action);
        };
    };

    func onError(error_text: Text) {   //ILDE: TBD: use SysLog
        Debug.print("onError:");
        Debug.print(debug_show(error_text));
    };

    func onCycleEnd(total_inst: Nat64) {   //ILDE: TBD: use SysLog
        Debug.print("onCycleEnd:");
        Debug.print(debug_show(total_inst));
    };

    stable let reader_mem = reader.Mem();
    var my_reader = reader.Reader<T.Action>({
        mem = reader_mem;
        //noarchive_id = noarchive_pid;
        ledger_id = ledger_pid;
        start_from_block = #id(0);//last; 
        // ILDE: I DONT FULLY GET THIS ONE:   {#id:Nat; #last};
        // id(i) means start from i, last means start from the last block (basically show nothing but n ew blocks)
        onError = onError; // If error occurs during following and processing it will return the error
        onCycleEnd = onCycleEnd; // Measure performance of following and processing transactions. Returns instruction count
        onRead = onRead;
        decodeBlock = decodeBlock;       //ILDE:Block -> ?Block for convenience in conversions
        getTimeFromAction = getTimeFromAction;
    });
    
    let noarchive = actor (Principal.toText(noarchive_pid)) : T.NoArchiveInterface;

    ignore Timer.setTimer<system>(#seconds 0, func () : async () {
        Debug.print("inside setTimer of reader");
        Debug.print("ledger pid from insider reader:"#debug_show(ledger_pid));
        await my_reader.start<system>();

        //await chain.start_archiveCycleMaintenance<system>(); 
    });
    // func encodeBlock(b: T.Action) : [rechain.ValueMap] {

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

    public func enable(): async ()   {
        await my_reader.enable();
    };
    public func disable(): async ()  {
        await my_reader.disable();
    };
    //     let ret = ?Blob.fromArray(RepIndy.hash_val(auxm1));
    //     return ret;
    // };

    // public query func compute_hash(auxm1: rechain.Value) : async ?Blob {
    //     let ret = ?Blob.fromArray(RepIndy.hash_val(auxm1));
    //     return ret;
    // };

    // public query func icrc3_get_blocks(args: rechain.GetBlocksArgs) : async rechain.GetBlocksResult{
    //     return chain.get_blocks(args);
    // };

    // public query func icrc3_get_archives(args: rechain.GetArchivesArgs) : async rechain.GetArchivesResult{
    //     return chain.get_archives(args);
    // };

    // var chain = rechain.Chain<T.Action, T.ActionError>({ 
    //     settings = ?{rechain.DEFAULT_SETTINGS with supportedBlocks = [];};// maxActiveRecords = 20; settleToRecords = 10; maxRecordsInArchiveInstance = 30;};
    //     mem = chain_mem;
    //     encodeBlock = encodeBlock;
    //     reducers = [balances.reducer];//, dedup.reducer];//, balancesIlde.reducer];  
    // });

    // var my_reader = reader.Reader<T.Action>({
    //     mem : reader.Mem;
    //     ledger_id : Principal;   // IMHERE: how do I pass the ledger principal from ts 
    //     start_from_block: {#id:Nat; #last};
    //     onError : (Text) -> (); // If error occurs during following and processing it will return the error
    //     onCycleEnd : (Nat64) -> (); // Measure performance of following and processing transactions. Returns instruction count
    //     onRead : [T.Action] -> ();
    //     decodeBlock : (Block) -> T.Action;
    // }) //<----IMHERE

    // public shared(msg) func check_archives_balance(): async () {
    //     return await chain.check_archives_balance();
    // };

    // ignore Timer.setTimer<system>(#seconds 0, func () : async () {
    //     await chain.start_archiving<system>();
    //     await chain.start_archiveCycleMaintenance<system>();

    //     //await chain.start_archiveCycleMaintenance<system>(); 
    // });

    // public shared(msg) func set_ledger_canister(): async () {
    //     chain_mem.canister := ?Principal.fromActor(Self);
    //     //chain.set_ledger_canister(Principal.fromActor(Self));
    // };

    // public shared(msg) func add_record(x: T.Action): async (DispatchResult) {
    //     //return icrc3().add_record<system>(x, null);

    //     Debug.print("exnum_:"#debug_show(exnum_));
    //     Debug.print("exnum:"#debug_show(exnum));

    //     let ret = chain.dispatch(x);  //handle error
    //     //add block to ledger

    //     return ret;


    // };

    // // ICRC-1
    // public shared ({ caller }) func icrc1_transfer(req : ICRC.TransferArg) : async ICRC.Result {
    //     let ret = transfer(caller, req);
    //     ret;
    // };

    // public query func icrc1_balance_of(acc: ICRC.Account) : async Nat {
    //     balances.get(acc)
    // };
 
    // private func transfer(caller:Principal, req:ICRC.TransferArg) : ICRC.Result {
    //     let from : ICRC.Account = {
    //         owner = caller;
    //         subaccount = req.from_subaccount;
    //     };

    //     let payload = if (from == config.MINTING_ACCOUNT) {   
    //         let pri_blob: Blob = Principal.toBlob(req.to.owner);
    //         let aux = req.to.subaccount;
    //         let to_blob: [Blob] = switch aux {
    //             case (?Blob) [pri_blob, Blob];
    //             case (_) [pri_blob];
    //         };
    //         #mint({
    //             to = to_blob;
    //             amt = req.amount;
    //         });
    //     } else if (req.to == config.MINTING_ACCOUNT) {
    //         let from_blob: [Blob] = switch (req.from_subaccount) {
    //             case (?Blob) [Blob];
    //             case (_) [("0": Blob)];
    //         };
    //         #burn({
    //             from = from_blob;
    //             amt = req.amount;
    //         });
    //     } else if (false){
    //         let fee:Nat = switch(req.fee) {
    //             case (?Nat) Nat;
    //             case (_) 0:Nat;
    //         };
    //         let pri_blob: Blob = Principal.toBlob(req.to.owner);
    //         let aux = req.to.subaccount;
    //         let to_blob: [Blob] = switch aux {
    //             case (?Blob) [pri_blob, Blob];
    //             case (_) [pri_blob];
    //         };
    //         let from_blob: [Blob] = switch (req.from_subaccount) {
    //             case (?Blob) [Blob];
    //             case (_) [("0": Blob)];
    //         };
    //         #transfer_from({
    //             to = to_blob;
    //             from = from_blob;
    //             amt = req.amount;
    //         });
    //     } else {
    //         let fee:Nat = switch(req.fee) {
    //             case (?Nat) Nat;
    //             case (_) 0:Nat;
    //         };
    //         let pri_blob: Blob = Principal.toBlob(req.to.owner);
    //         let aux = req.to.subaccount;
    //         let to_blob: [Blob] = switch aux {
    //             case (?Blob) [pri_blob, Blob];
    //             case (_) [pri_blob];
    //         };
    //         let from_blob: [Blob] = switch (req.from_subaccount) {
    //             case (?Blob) [Blob];
    //             case (_) [("0": Blob)];
    //         };
    //         #transfer({
    //             to = to_blob;
    //             fee = fee;
    //             from = from_blob;
    //             amt = req.amount;
    //         });
    //     };

    //     let ts:Nat64 = switch (req.created_at_time) {
    //         case (?Nat64) Nat64;
    //         case (_) 0:Nat64;
    //     };

    //     let action = {
    //         caller = caller;
    //         ts = ts;
    //         created_at_time = req.created_at_time;
    //         memo = req.memo;
    //         fee = req.fee;
    //         payload = payload;
    //     };

    //     let ret = chain.dispatch(action);

    //     return ret;

    // };


    // public type DispatchResult = {#Ok : Nat;  #Err: T.ActionError };

    // public func dispatch(actions: [T.Action]): async [DispatchResult] {
    //     Array.map(actions, func(x: T.Action): DispatchResult = chain.dispatch(x));
    // };

};