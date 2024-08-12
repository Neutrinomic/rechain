//import Ledger "./icrc_ledger";
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
        ledger_id : Principal;
        start_from_block: {#id:Nat; #last};
        onError : (Text) -> (); // If error occurs during following and processing it will return the error
        onCycleEnd : (Nat64) -> (); // Measure performance of following and processing transactions. Returns instruction count
        onRead : [A] -> ();
        decodeBlock : (?Block) -> A;       //ILDE:Block -> ?Block for convenience in conversions
        getTimeFromAction : A -> Nat64;    //ILDE:added
    }) {
        var started = false;
        let ledger = actor (Principal.toText(ledger_id)) : T.ICRC3Interface;//Ledger.Self;//<<<----IMHERE I need the interface
        var lastTxTime : Nat64 = 0;

        private func cycle() : async () {
            Debug.print("in cycle()");
            if (not started) return;
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            if (mem.last_indexed_tx == 0) {
                switch(start_from_block) {
                    case (#id(id)) {
                        mem.last_indexed_tx := id;
                    };
                    case (#last) { // ILDE: <---------------------THIS SEEMS POINTLESS
                        let rez = await ledger.icrc3_get_blocks([{
                            start = 0;
                            length = 0;
                        }]);
                        mem.last_indexed_tx := rez.log_length -1;   //ILDE: 0 - 1 = -1...WHY????
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
                    onRead(decoded_actions);//rez.blocks);//transactions);

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
        };

        /// Returns the last tx time or the current time if there are no more transactions to read
        public func getReaderLastTxTime() : Nat64 { 
            lastTxTime;
        };

        private func cycle_shell() : async () {
            try {
                // We need it async or it won't throw errors
                await cycle();
            } catch (e) {
                onError("cycle:" # Principal.toText(ledger_id) # ":" # Error.message(e));
            };

            if (started) ignore Timer.setTimer<system>(#seconds 2, cycle_shell);
        };

        public func start<system>(): async () {
            if (started) Debug.print("already started");//Debug.trap("already started");
            //started := true;
            ignore Timer.setTimer<system>(#seconds 2, cycle_shell);
        };

        public func enable() : async () {
            started := true;
        };

        public func disable() : async () {
            started := false;
        }
    };

};