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
import Error "mo:base/Error";
import noarchive "../src/noarchive";

actor class reader_reader(ledger_pid : Principal) = Self {//, noarchive_pid : Principal) = Self {
    // -- Ledger configuration
    let config_noarchive : T.Config = {
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
        config = config_noarchive;
        mem = balances_mem;
    });

    // -- Reducer : Deduplication

    stable let dedup_mem = Deduplication.Mem();
    let dedup = Deduplication.Deduplication({
        config = config_noarchive;
        mem = dedup_mem;
    });

    // -- Chain

    stable let chain_mem = noarchive.Mem();
    var chain = noarchive.RechainNoArchive<T.Action, T.ActionError>({ 
        //settings = ?{rechain.DEFAULT_SETTINGS with supportedBlocks = [];maxActiveRecords = 60; settleToRecords = 30; maxRecordsInArchiveInstance = 100;};
        mem = chain_mem;
        //encodeBlock = encodeBlock;
        reducers = [balances.reducer];//, dedup.reducer];//, balancesIlde.reducer];  
    });

    func decodeBlock(block: ?Trechain.Value) : T.Action {      
        
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
                            // Debug.print("tx");
                            // Debug.print(debug_show(mymap));
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

    func myOnRead(actions: [T.Action]): () {
        var i = 0;
        var err : T.NoArchiveDispatchReturn = #Ok(0);
        //let noarchive = actor (Principal.toText(noarchive_pid)) : T.NoArchiveInterface;

        for(action in actions.vals()) {
            //try{
                let ret = chain.dispatch(action);   // <---------call a sync dispatch 
            //} catch e {Debug.print("IMHERE2");Debug.print("rerror:"#debug_show(Error.code(e))#", e message:"#debug_show(Error.message(e)));};
        
            i := i+1;
        };
    };

    func myOnReadNew(actions: [T.Action], id_nat : Nat): () {
        myOnRead(actions);
    };

    func onError(error_text: Text) {   //ILDE: TBD: use SysLog
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
        onRead = myOnRead;
        onReadNew = myOnReadNew;
        decodeBlock = decodeBlock;       //ILDE:Block -> ?Block for convenience in conversions
        getTimeFromAction = getTimeFromAction;
        maxParallelRequest = 40;
    });
    
    //let noarchive = actor (Principal.toText(noarchive_pid)) : T.NoArchiveInterface;

    ignore Timer.setTimer<system>(#seconds 0, func () : async () {

        await my_reader.start_timers<system>();

    });
      
    public func start_timer(): async () {
         await my_reader.start_timer_flag();
    };
    public func stop_timer(): async () {
         await my_reader.stop_timer_flag();
    };

    public query func icrc1_balance_of(acc: ICRC.Account) : async Nat {
        balances.get(acc);
    };
    

};