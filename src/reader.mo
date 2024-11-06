import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Vector "mo:vector";
import Debug "mo:base/Debug";
import Prim "mo:⛔";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";
import T "./types";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Ver1 "./memory/reader/v1";
import MU "mo:mosup";
module {
    public module Mem {
        public module Reader {
            public let V1 = Ver1.Reader;
        };
    };

    let VM = Mem.Reader.V1;

    public type Block = T.Value;

    type BlocksUnordered = {
        start : Nat;
        transactions : [T.Value];
    };
        

    public type nullblock = ?Block;

    public func sortBlocksById(blocks: [{block : nullblock; id : Nat}]) : [nullblock] { 
        func my_compare(a:{block : nullblock; id : Nat}, b:{block : nullblock; id : Nat}) : {#less; #equal; #greater} {
            if (a.id < b.id) { #less } else if (a.id == b.id) { #equal } else { #greater };
        };
        let sorted_nullblocks_wid = Array.sort<{block : nullblock; id : Nat}>(blocks:[{block : nullblock; id : Nat}], my_compare);
        let sorted_nullblocks = Array.map<{block : nullblock; id : Nat}, nullblock>(sorted_nullblocks_wid, func x = x.block);
        sorted_nullblocks;
    };

    public class Reader<system, A>({
        xmem : MU.MemShell<VM.Mem>;
        ledger_id : Principal;
        start_from_block: {#id:Nat; #last};
        onError : (Text) -> (); 
        onCycleEnd : (Nat64) -> (); 
        onRead : ([A], Nat) -> (); 
        decodeBlock : (?Block) -> A;   
        getTimeFromAction : A -> Nat64;   
        maxParallelRequest : Nat;
    }) {
        let mem = MU.access(xmem);

        let ledger = actor (Principal.toText(ledger_id)) : T.ICRC3Interface; 
        var lastTxTime : Nat64 = 0;
        let maxTransactionsInCall:Nat = 2000;
        var lock:Int = 0;
        let MAX_TIME_LOCKED:Int = 120_000_000_000;


        private func cycle() : async () {


            let now = Time.now();
            if (now-lock < MAX_TIME_LOCKED) return
            lock := now;

            let inst_start = Prim.performanceCounter(1); 

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
                        mem.last_indexed_tx := rez.log_length -1; 
                    };
                };
            };

            let rez = await ledger.icrc3_get_blocks([{
                start = mem.last_indexed_tx;
                length = maxTransactionsInCall * maxParallelRequest; 
            }]);


            if (rez.archived_blocks.size() == 0) { 
                
                let sorted_blocks = sortBlocksById(rez.blocks);

                let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
 
                onRead(decoded_actions, mem.last_indexed_tx);
          
                mem.last_indexed_tx += rez.blocks.size();

                if (rez.blocks.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);

            } else {
               
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
                
                let unordered = Vector.new<myBlocksUnorderedtype>(); 
                
                let args_maxsize_ext = Vector.new<[GetBlocksRequest]>();
                
                for (atx in rez.archived_blocks.vals()) {
                    let args = atx.args;
                    let args_maxsize = Vector.new<[GetBlocksRequest]>();
                    for (arg in args.vals()) {
                        let arg_starts = Array.tabulate<Nat>(Nat.min(maxParallelRequest, 1 + arg.length/maxTransactionsInCall), func(i) = arg.start + i*maxTransactionsInCall); 
                        
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

                    let aux = args_ext[i];
                    for (j in Iter.range(0, aux.size() - 1)) {
                        let args_exti_j = aux[j];
                        let promise = atx.callback([args_exti_j]);
                        buf := List.push(promise, buf); 
                    }; 
                    i := i + 1;
                };
                for (promise in List.toIter(buf)) {
                  data := List.push(await promise, data);  
                };
                let chunks : [T.GetTransactionsResult] = List.toArray(data); 

                var chunk_idx = 0;
                for (chunk in chunks.vals()) {
                    if (chunk.blocks.size() > 0) { 
                        if ((chunk_idx < (chunks.size() - 1:Nat)) and (chunk.blocks.size() != maxTransactionsInCall)) {  

                            onError("chunk.blocks.size() != " # Nat.toText(maxTransactionsInCall) # " | chunk.blocks.size(): " # Nat.toText(chunk.blocks.size())); 
                            
                            lock := 0;
                            return ;
                        };

                        Vector.add(
                            unordered,
                            {
                                start = chunk.blocks[0].id; 
                                transactions = chunk.blocks;
                            },
                        );
                    };
                    chunk_idx += 1;
                };

                let sorted = Array.sort<myBlocksUnorderedtype>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    if (u.start != mem.last_indexed_tx) {
                        Debug.print("THIS:"#debug_show(u.start)#":"#debug_show(mem.last_indexed_tx));
                        onError("u.start != mem.last_indexed_tx | u.start: " # Nat.toText(u.start) # " mem.last_indexed_tx: " # Nat.toText(mem.last_indexed_tx) # " u.transactions.size(): " # Nat.toText(u.transactions.size()));
                        lock := 0;
                        return ;
                    };

                    let sorted_blocks = sortBlocksById(u.transactions);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
          
                    onRead(decoded_actions, mem.last_indexed_tx);
                  
                    mem.last_indexed_tx += u.transactions.size();

                    if (u.transactions.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);

                };   
                if (rez.blocks.size() != 0) { 

                    let sorted_blocks = sortBlocksById(rez.blocks);
                    let decoded_actions: [A] = Array.map<?Block,A>(sorted_blocks, decodeBlock);
                    onRead(decoded_actions, mem.last_indexed_tx);

                    mem.last_indexed_tx += rez.blocks.size();

                    if (rez.blocks.size() != 0) lastTxTime := getTimeFromAction(decoded_actions[Array.size(decoded_actions) - 1]);
                };
            };

            let inst_end = Prim.performanceCounter(1); 
            onCycleEnd(inst_end - inst_start);

            lock := 0; 
           
        };

        public func getReaderLastTxTime() : Nat64 { 
            lastTxTime;
        };


        ignore Timer.recurringTimer<system>(#seconds 2, cycle);
    };

};