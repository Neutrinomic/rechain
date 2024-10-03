import Principal "mo:base/Principal";
import ICRC "./ledger/icrc";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Deduplication "./ledger/reducers/deduplication";
import T "./ledger/types";
import Trechain "../src/types";
import Balances "./ledger/reducers/balances";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import Text "mo:base/Text";
import reader "../src/reader";
import noarchive "../src/noarchive";

actor class reader_reader(ledger_pid : Principal) = Self {
    let config_noarchive : T.Config = {
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
        config = config_noarchive;
        mem = balances_mem;
    });

    stable let dedup_mem = Deduplication.Mem();
    let dedup = Deduplication.Deduplication({
        config = config_noarchive;
        mem = dedup_mem;
    });

    stable let chain_mem = noarchive.Mem();
    var chain = noarchive.RechainNoArchive<T.Action, T.ActionError>({ 
        mem = chain_mem;
        reducers = [balances.reducer]; 
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
            memo = ?memo;
            caller = Principal.fromBlob(caller);
            fee = ?fee;
            payload = switch(btype) {
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

        return_action;
    };

    func getTimeFromAction(action: T.Action) : Nat64 {
        action.ts;
    };

    func myOnRead(actions: [T.Action]): () {
        var i = 0;
        var err : T.NoArchiveDispatchReturn = #Ok(0);

        for(action in actions.vals()) {
            let ret = chain.dispatch(action);  
           
            i := i+1;
        };
    };

    func myOnReadNew(actions: [T.Action], id_nat : Nat): () {
        myOnRead(actions);
    };

    func onError(error_text: Text) {   
        
    };

    func onCycleEnd(total_inst: Nat64) {  

    };

    stable let reader_mem = reader.Mem();

    var my_reader = reader.Reader<T.Action>({
        mem = reader_mem;
        ledger_id = ledger_pid;
        start_from_block = #id(0);
        onError = onError; 
        onCycleEnd = onCycleEnd; 
        onRead = myOnReadNew;
        decodeBlock = decodeBlock;      
        getTimeFromAction = getTimeFromAction;
        maxParallelRequest = 40;
    });

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