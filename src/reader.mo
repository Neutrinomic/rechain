import Ledger "./icrc_ledger";
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

// From https://github.com/Neutrinomic/devefi_icrc_ledger/tree/master
module {
    public type Block = ICRC3.Value;

    public type Mem = {
            var last_indexed_tx : Nat;
        };

    type BlocksUnordered = {
            start : Nat;
            transactions : [ICRC3.Value];
        };
        
    public func Mem() : Mem {
            return {
                var last_indexed_tx = 0;
            };
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
        decodeBlock : (Block) -> A;
    }) {
        var started = false;
        let ledger = actor (Principal.toText(ledger_id)) : Ledger.Self;
        var lastTxTime : Nat64 = 0;

        private func cycle() : async () {
            if (not started) return;
            let inst_start = Prim.performanceCounter(1); // 1 is preserving with async

            if (mem.last_indexed_tx == 0) {
                switch(start_from_block) {
                    case (#id(id)) {
                        mem.last_indexed_tx := id;
                    };
                    case (#last) {
                        let rez = await ledger.get_transactions({
                            start = 0;
                            length = 0;
                        });
                        mem.last_indexed_tx := rez.log_length -1;
                    };
                };
            };

            let rez = await ledger.get_transactions({
                start = mem.last_indexed_tx;
                length = 1000;
            });

            if (rez.archived_transactions.size() == 0) {
                // We can just process the transactions that are inside the ledger and not inside archive
                onRead(rez.transactions);
                mem.last_indexed_tx += rez.transactions.size();
                if (rez.transactions.size() < 1000) {
                    // We have reached the end, set the last tx time to the current time
                    lastTxTime := Nat64.fromNat(Int.abs(Time.now()));
                } else {
                    // Set the time of the last transaction
                    lastTxTime := rez.transactions[rez.transactions.size() - 1].timestamp;
                };
            } else {
                // We need to collect transactions from archive and get them in order
                let unordered = Vector.new<BlocksUnordered>(); // Probably a better idea would be to use a large enough var array

                for (atx in rez.archived_transactions.vals()) {
                    let txresp = await atx.callback({
                        start = atx.start;
                        length = atx.length;
                    });

                    Vector.add(
                        unordered,
                        {
                            start = atx.start;
                            transactions = txresp.transactions;
                        },
                    );
                };

                let sorted = Array.sort<BlocksUnordered>(Vector.toArray(unordered), func(a, b) = Nat.compare(a.start, b.start));

                for (u in sorted.vals()) {
                    assert (u.start == mem.last_indexed_tx);
                    onRead(u.transactions);
                    mem.last_indexed_tx += u.transactions.size();
                };

                if (rez.transactions.size() != 0) {
                    onRead(rez.transactions);
                    mem.last_indexed_tx += rez.transactions.size();
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

            if (started) ignore Timer.setTimer(#seconds 2, cycle_shell);
        };

        public func start() {
            if (started) Debug.trap("already started");
            started := true;
            ignore Timer.setTimer(#seconds 2, cycle_shell);
        };

        public func stop() {
            started := false;
        }
    };

};