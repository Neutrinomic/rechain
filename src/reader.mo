import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Vector "mo:vector";
import Debug "mo:base/Debug";
import Prim "mo:⛔";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";

import T "./types";
import List "mo:base/List";
import Iter "mo:base/Iter";


// From https://github.com/Neutrinomic/devefi_icrc_ledger/tree/master
module {
    public type Block = T.Value;

    public type Mem = {
            var last_indexed_tx : Nat;
        };

    type BlocksUnordered = {
            start : Nat;
            transactions : [T.Value];
        };
        
    public func Mem() : Mem {
            return {
                var last_indexed_tx = 0;
            };
        };

    // Sorting blocks by id and removing the ids so we can pass to the decode method
    public type nullblock = ?Block;

    public func sortBlocksById(blocks: [{block : nullblock; id : Nat}]) : [nullblock] { 
        func my_compare(a:{block : nullblock; id : Nat}, b:{block : nullblock; id : Nat}) : {#less; #equal; #greater} {
            if (a.id < b.id) { #less } else if (a.id == b.id) { #equal } else { #greater };
        };
        let sorted_nullblocks_wid = Array.sort<{block : nullblock; id : Nat}>(blocks:[{block : nullblock; id : Nat}], my_compare);
        let sorted_nullblocks = Array.map<{block : nullblock; id : Nat}, nullblock>(sorted_nullblocks_wid, func x = x.block);
        //Array.filter<nullblock>(sorted_nullblocks, func x = (x!=null));
    };

    // follows ICRC3 backlog and sends transactions to onRead ordered. Converts generic value to action using decodeBlock
    // Problems:
    // - make it use ICRC3 methods
    // - you get Generic Value Blocks, need to be converted with decodeBlock then passed to onRead


    public class Reader<A>({
        mem : Mem;
        //noarchive_id : Principal;
        ledger_id : Principal;
        start_from_block: {#id:Nat; #last};
        onError : (Text) -> (); // If error occurs during following and processing it will return the error
        onCycleEnd : (Nat64) -> (); // Measure performance of following and processing transactions. Returns instruction count
        onRead : [A] -> ();
        onReadNew : ([A], Nat) -> ();  //ILDE: I am not sure what this new paramter is meant for (why do we pass 'mem.last_indexed_tx'?)
        decodeBlock : (?Block) -> A;       //ILDE:Block 
        getTimeFromAction : A -> Nat64;    //ILDE:added
        maxParallelRequest : Nat; // 40 is the default maximum number of parallel request
    }) {
        var started = false; // If this flag is off, the reader does nothing

        let ledger = actor (Principal.toText(ledger_id)) : T.ICRC3Interface; 
        var lastTxTime : Nat64 = 0;
        let maxTransactionsInCall:Nat = 2000;//50;//ONLY FOR DEBUG. PUT 2000 in production. Consistent with Rechain minsize of archives!!!!!!!!!!!!;
        
        var lock:Int = 0;
        let MAX_TIME_LOCKED:Int = 120_000_000_000; // 120 seconds


        private func cycleNew() : async () {

            if (not started) return;

            let now = Time.now();
            if (now-lock < MAX_TIME_LOCKED) return
            lock := now;

            //if (not started) return false;
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            if (mem.last_indexed_tx == 0) { // ILDE: last_indexed_tx: keeps the index of the block that is next to be read (not yet read)
                switch(start_from_block) {  // ILDE: start_from_block (#id(id) or #last): #last means 
                    case (#id(id)) {
                        mem.last_indexed_tx := id;
                    };
                    case (#last) {
                        let rez = await ledger.icrc3_get_blocks([{//get_transactions({
                            start = 0;
                            length = 0;
                        }]);
                        mem.last_indexed_tx := rez.log_length -1; // ILDE: it assigns last_indexed_t to the last block index in the ledger (start reading from the last)
                    };
                };
            };

            let rez = await ledger.icrc3_get_blocks([{//get_transactions({
                start = mem.last_indexed_tx;
                length = maxTransactionsInCall * maxParallelRequest; //ILDE: new constant 2000*40 (before 1000)
            }]);
            //NEWILDE

            let quick_cycle:Bool = if (rez.log_length > mem.last_indexed_tx + 1000) true else false; // ILDE (not used since recurrent timer): flag returned by cycle: true if we are reading at least 1000 blocks in this cycle. Not sure why it return it???

            if (rez.archived_blocks.size() == 0) { //rez.archived_transactions.size() == 0) { //ILDE: case not reading from archive canisters in this cycle
                
                let sorted_blocks = sortBlocksById(rez.blocks);

                let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
 
                onReadNew(decoded_actions, mem.last_indexed_tx);
          
                mem.last_indexed_tx += rez.blocks.size();//transactions.size();

                if (rez.blocks.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);
                //ILDE: NEED TO DISCUSS: INSTEAD OF rez.transactions[rez.transactions.size() - 1].timestamp;

            } else { //ILDE: case where we need to access archive canisters
                // We need to collect transactions from archive and get them in order
                type TransactionUnordered = {
                    start : Nat;
                    transactions : [?Block];
                };
                type GetBlocksRequest = { 
                    start : Nat; 
                    length : Nat; 
                };
                type TransactionRange = { transactions : [Block] };

                type myBlocksUnorderedtype = {
                    start : Nat;
                    transactions : [{block : ?Block; id : Nat}];
                };
                //ILDE let unordered = Vector.new<BlocksUnordered>(); // Probably a better idea would be to use a large enough var array
                let unordered = Vector.new<myBlocksUnorderedtype>(); 
                //ILDE: extend args such that all blocks are of size maxTransactionsInCall or smaller
                let args_maxsize_ext = Vector.new<[GetBlocksRequest]>();
                //let args_starts = Vector.new<[Nat]>();
                for (atx in rez.archived_blocks.vals()) {
                    let args = atx.args;
                    let args_maxsize = Vector.new<[GetBlocksRequest]>();
                    for (arg in args.vals()) {
                        let arg_starts = Array.tabulate<Nat>(Nat.min(maxParallelRequest, 1 + arg.length/maxTransactionsInCall), func(i) = arg.start + i*maxTransactionsInCall); //ILDE: THIS seems an overkill
                        //ILDE: where is this 40 coming from???
                        let arg_starts_bound = Array.map<Nat, GetBlocksRequest>( arg_starts, func(i) = {start = i; length = if (i - arg.start:Nat+maxTransactionsInCall <= arg.length) maxTransactionsInCall else arg.length + arg.start - i } );
                        Vector.add(args_maxsize, arg_starts_bound,);
                    };
                    let arg_ext : [[GetBlocksRequest]] = Vector.toArray(args_maxsize);
                    let arg_ext_flat : [GetBlocksRequest] = Array.flatten(arg_ext);
                    Vector.add(args_maxsize_ext, arg_ext_flat,);
                };
                let args_ext : [[GetBlocksRequest]] = Vector.toArray(args_maxsize_ext);

                var buf = List.nil<async T.GetTransactionsResult>();
                var data = List.nil<T.GetTransactionsResult>();

                var i = 0;
                for (atx in rez.archived_blocks.vals()) {
                    // The calls are sent here without awaiting anything

                    let aux = args_ext[i];
                    for (j in Iter.range(0, aux.size() - 1)) {
                        let args_exti_j = aux[j];
                        let promise = atx.callback([args_exti_j]);
                        buf := List.push(promise, buf); 
                    };  
                    //let promise = atx.callback(args_ext[i]);   
                    //buf := List.push(promise, buf); 
                    i := i + 1;
                };
                //I? Why is this faster? because we make all the call at once??
                for (promise in List.toIter(buf)) {
                  // Await results of all promises. We recieve them in sequential order
                  data := List.push(await promise, data);  
                };
                let chunks : [T.GetTransactionsResult] = List.toArray(data); // I: note the type allows to identify the id of every block
               
                //I: copied from devefi and adapted (look at comments with I)

                var chunk_idx = 0;
                for (chunk in chunks.vals()) {
                    if (chunk.blocks.size() > 0) { // I: transactions -> blocks
                        // If chunks (except the last one) are smaller than 2000 tx then implementation is strange
                        if ((chunk_idx < (chunks.size() - 1:Nat)) and (chunk.blocks.size() != maxTransactionsInCall)) {  //I: args.size() -> chunks.size()

                            onError("chunk.blocks.size() != " # Nat.toText(maxTransactionsInCall) # " | chunk.blocks.size(): " # Nat.toText(chunk.blocks.size())); //I: transactions -> blocks
                            
                            lock := 0; // unlock the cycle method
                            return ;//false;
                        };

                        Vector.add(
                            unordered,
                            {
                                start = chunk.blocks[0].id; //args_starts[chunk_idx] -> blocks[0].id
                                transactions = chunk.blocks; //transactions -> blocks;
                            },
                        );
                    };
                    chunk_idx += 1;
                };

                //I: we need to transform from "myBlocksUnorderedtype" to "TransactionUnordered" (required by the new algorithm)
                // type myBlocksUnorderedtype = {
                //     start : Nat;
                //     transactions : [{block : ?Block; id : Nat}];
                // };
                // type TransactionUnordered = {
                //     start : Nat;
                //     transactions : [?Block];
                // };
                
                //NEW
                // let tx_unordered = Vector.new<TransactionUnordered>();
                // let unordered_array : [myBlocksUnorderedtype] = Vector.toArray(unordered);
                // for (tx in unordered_array.vals()) {
                //     let aux = tx.transactions;
                //     let aux_tx : [?Block] = Array.tabulate<?Block>(aux.size(), func i = aux[i].block);
                //     Vector.add(tx_unordered, {start = tx.start; transactions=aux_tx},);
                // };
                //ENDNEW

                let sorted = Array.sort<myBlocksUnorderedtype>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    if (u.start != mem.last_indexed_tx) {
                        Debug.print("THIS:"#debug_show(u.start)#":"#debug_show(mem.last_indexed_tx));
                        onError("u.start != mem.last_indexed_tx | u.start: " # Nat.toText(u.start) # " mem.last_indexed_tx: " # Nat.toText(mem.last_indexed_tx) # " u.transactions.size(): " # Nat.toText(u.transactions.size()));
                        lock := 0; // unlock the cycle method
                        return ;
                    };

                    let sorted_blocks = sortBlocksById(u.transactions);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
          
                    onReadNew(decoded_actions, mem.last_indexed_tx);//rez.blocks);//transactions);
                  
                    mem.last_indexed_tx += u.transactions.size();

                    if (u.transactions.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);

                };   

                //I: in our case, rez.first_index does not exist, so I comment the whole internal if
                if (rez.blocks.size() != 0) { //I: transactions -> blocks

                    let sorted_blocks = sortBlocksById(rez.blocks);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
                    onReadNew(decoded_actions, mem.last_indexed_tx);

                    mem.last_indexed_tx += rez.blocks.size();//transactions.size();

                    if (rez.blocks.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);

                };
            };

            let inst_end = Prim.performanceCounter(1); // 1 is preserving with async
            onCycleEnd(inst_end - inst_start);

            lock := 0; // unlock the cycle method
            //quick_cycle;
        };

        private func cycle() : async () {
            
            if (not started) return;

            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            if (mem.last_indexed_tx == 0) {
                switch(start_from_block) {
                    case (#id(id)) {
                        mem.last_indexed_tx := id;
                    };
                    case (#last) { 
                        let rez = await ledger.icrc3_get_blocks([{
                            start = 0;
                            length = 0;
                        }]);
                        mem.last_indexed_tx := rez.log_length -1;  // It gives info of ldeger length
                    };
                };
            };

            let rez = await ledger.icrc3_get_blocks([{
                start = mem.last_indexed_tx;
                length = 1000;
            }]);

            if (rez.archived_blocks.size() == 0) {
                // We can just process the transactions that are inside the ledger and not inside archive
            
                //ILDE
                let sorted_blocks = sortBlocksById(rez.blocks);

                let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);

                onRead(decoded_actions);//rez.blocks);//transactions);
                
                mem.last_indexed_tx += rez.blocks.size();//transactions.size();
                if (rez.blocks.size() < 1000) {//transactions.size() < 1000) {
                    // We have reached the end, set the last tx time to the current time
                    lastTxTime := Nat64.fromNat(Int.abs(Time.now())); //ILDE: possible bug this should use "getTimeFromAction"
                } else {
                    // Set the time of the last transaction
                    // ILDE: I need to use 
                    //before: lastTxTime := rez.transactions[rez.transactions.size() - 1].timestamp;
                    lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);
                };
            } else {   
                // We need to collect transactions from archive and get them in order

                type myBlocksUnorderedtype = {
                    start : Nat;
                    transactions : [{block : ?Block; id : Nat}];
                };

                //ILDE let unordered = Vector.new<BlocksUnordered>(); // Probably a better idea would be to use a large enough var array
                let unordered = Vector.new<myBlocksUnorderedtype>(); 

                //ILDE
                for (atx in rez.archived_blocks.vals()) {
                    let i = 0;
                    let txresp = await atx.callback(atx.args);//{
                    //     start = atx.args[i].start;
                    //     length = atx.args[i].length;
                    // });
                    // blocks : [{block : ?Value; id : Nat}];
                    
                    Vector.add(
                        unordered,
                        {
                            start = atx.args[i].start;
                            transactions = txresp.blocks;
                        },
                    );
                };

                //BEFORE
                // for (atx in rez.archived_transactions.vals()) {
                //     let txresp = await atx.callback({
                //         start = atx.start;
                //         length = atx.length;
                //     });

                //     Vector.add(
                //         unordered,
                //         {
                //             start = atx.start;
                //             transactions = txresp.transactions;
                //         },
                //     );
                // };

                //ILDE let sorted = Array.sort<BlocksUnordered>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));
                let sorted = Array.sort<myBlocksUnorderedtype>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

               

                //<----IMHERE
                for (u in sorted.vals()) {
                    assert (u.start == mem.last_indexed_tx);
                    //onRead(u.transactions);
                    //ILDE
                    let sorted_blocks = sortBlocksById(u.transactions);//blocks);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);


                    mem.last_indexed_tx += u.transactions.size();
                    //rez.blocks.size();//transactions.size();
                };

                //ILDE
                // if (rez.transactions.size() != 0) {
                //     onRead(rez.transactions);
                //     mem.last_indexed_tx += rez.transactions.size();
                // };
                if (rez.blocks.size() != 0) {
                    let sorted_blocks = sortBlocksById(rez.blocks);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);

                    onRead(decoded_actions);//rez.blocks);//transactions);
                    //onRead(rez.transactions);
                    mem.last_indexed_tx += rez.blocks.size();
                };
            };

            let inst_end = Prim.performanceCounter(1); // 1 is preserving with async
            onCycleEnd(inst_end - inst_start);
            // Debug.print("started:"#debug_show(started));
        };

        /// Returns the last tx time or the current time if there are no more transactions to read
        public func getReaderLastTxTime() : Nat64 { 
            lastTxTime;
        };

        private func cycle_shell() : async () {
            if (started == true) {
                try {
                    // We need it async or it won't throw errors
                    let aux = await cycleNew();
                } catch (e) {
                    onError("cycle:" # Principal.toText(ledger_id) # ":" # Error.message(e));
                };
            };

            if (started == true) ignore Timer.setTimer<system>(#seconds 2, cycle_shell);
        };

        public func start_timers<system>(): async () {
            // if (started) Debug.print("already started");//Debug.trap("already started");
            // started := true;
            
            ignore Timer.setTimer<system>(#seconds 2, cycle_shell);
            //ignore Timer.setTimer<system>(#seconds 2, cycleNew);
        };

        public func start_timer_flag() : async () {
           started := true;
        };

        public func stop_timer_flag() : async () {
           started := false;
        };
    };

};