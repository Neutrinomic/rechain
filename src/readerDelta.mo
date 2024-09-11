import Principal "mo:base/Principal";
import Error "mo:base/Error";
import Timer "mo:base/Timer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Vector "mo:vector";
import Debug "mo:base/Debug";
import Prim "mo:⛔";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";
import List "mo:base/List";
import Iter "mo:base/Iter";
import T "./types";

module {
    public type Transaction = T.Value;

    public type Mem = {
            var last_indexed_tx : Nat;
        };

    type TransactionUnordered = {
            start : Nat;
            blocks : [{block: ?T.Value; id:Nat}];
        };
        
    public func Mem() : Mem {
            return {
                var last_indexed_tx = 0;
            };
        };

    public class Reader({
        mem : Mem;
        ledger_id : Principal;
        start_from_block: {#id:Nat; #last};
        onError : (Text) -> (); // If error occurs during following and processing it will return the error
        onCycleEnd : (Nat64) -> (); // Measure performance of following and processing transactions. Returns instruction count
        onRead : ([{block: ?T.Value; id:Nat}]) -> ();
    }) {
        var started = false;
        let ledger = actor (Principal.toText(ledger_id)) : T.ICRC3Interface;

        let maxTransactionsInCall:Nat = 2000;

        var lock:Int = 0;
        let MAX_TIME_LOCKED:Int = 120_000_000_000; // 120 seconds

        let ARCHCALLS_PER_CYCLE = 40;

        private func cycle() : async () {
            if (not started) return;
            
            let now = Time.now();
            if (now - lock < MAX_TIME_LOCKED) return;
            lock := now;
            onError("cycle started");
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
                        mem.last_indexed_tx := rez.log_length -1;
                    };
                };
            };
            let query_start = mem.last_indexed_tx;
            
            let rez = try {
                await ledger.icrc3_get_blocks([{
                start = query_start;
                length = maxTransactionsInCall * ARCHCALLS_PER_CYCLE;
            }]);
            } catch (e) {
                onError("error in icrc3_get_blocks: " # Error.message(e));
                lock := 0;
                return;
            };

            if (query_start != mem.last_indexed_tx) {lock:=0; return;};

            if (rez.archived_blocks.size() == 0) {
                // We can just process the transactions that are inside the ledger and not inside archive
                onRead(rez.blocks);
                mem.last_indexed_tx += rez.blocks.size();
         
            
            } else {
                // We need to collect transactions from archive and get them in order
                let unordered = Vector.new<TransactionUnordered>(); // Probably a better idea would be to use a large enough var array
                onError("working on archived blocks");

                for (atx in rez.archived_blocks.vals()) {
                    let args_starts = Array.tabulate<Nat>(Nat.min(ARCHCALLS_PER_CYCLE, 1 + atx.args[0].length/maxTransactionsInCall), func(i) = atx.args[0].start + i*maxTransactionsInCall);
                    let args = Array.map<Nat, T.TransactionRange>( args_starts, func(i) = {start = i; length = if (i - atx.args[0].start:Nat+maxTransactionsInCall <= atx.args[0].length) maxTransactionsInCall else atx.args[0].length + atx.args[0].start - i } );

                    onError("args_starts: " # debug_show(args));


                    var buf = List.nil<async T.GetTransactionsResult>();
                    var data = List.nil<T.GetTransactionsResult>();
                    for (arg in args.vals()) {
                        // The calls are sent here without awaiting anything
                        let promise = atx.callback([arg]);
                        buf := List.push(promise, buf); 
                    };

                    for (promise in List.toIter(buf)) {
                        // Await results of all promises. We recieve them in sequential order
                        data := List.push(await promise, data);
                    };
                    let chunks = List.toArray(data);
                    
                    var chunk_idx = 0;
                    for (chunk in chunks.vals()) {
                        if (chunk.blocks.size() > 0) {
                            // If chunks (except the last one) are smaller than 2000 tx then implementation is strange
                            if ((chunk_idx < (args.size() - 1:Nat)) and (chunk.blocks.size() != maxTransactionsInCall)) {

                                onError("chunk.transactions.size() != " # Nat.toText(maxTransactionsInCall) # " | chunk.transactions.size(): " # Nat.toText(chunk.blocks.size()));
                                lock := 0;
                                return;
                            };
                        Vector.add(
                            unordered,
                            {
                                start = args_starts[chunk_idx];
                                blocks = chunk.blocks;
                            },
                        );
                        };
                        chunk_idx += 1;
                    };
                };

                let sorted = Array.sort<TransactionUnordered>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    if (u.start != mem.last_indexed_tx) {
                        onError("u.start != mem.last_indexed_tx | u.start: " # Nat.toText(u.start) # " mem.last_indexed_tx: " # Nat.toText(mem.last_indexed_tx) # " u.transactions.size(): " # Nat.toText(u.blocks.size()));
                        lock := 0;
                        return;
                    };
                    onRead(u.blocks);
                    mem.last_indexed_tx += u.blocks.size();
                };


                if (rez.blocks.size() != 0) {
                    onRead(rez.blocks);
                    mem.last_indexed_tx += rez.blocks.size();
                };
            };

            let inst_end = Prim.performanceCounter(1); // 1 is preserving with async
            onCycleEnd(inst_end - inst_start);

            lock := 0;
        };

  


        public func start<system>() {
            if (started) Debug.trap("already started");
            started := true;
            ignore Timer.recurringTimer<system>(#seconds 2, cycle);
        };

        public func stop() {
            started := false;
        }
    };

};