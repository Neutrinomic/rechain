import MU "mo:mosup";
import Map "mo:map/Map";
import SWB "mo:swbstable/Stable";
import CertTree "mo:ic-certification/CertTree";

module {
    public module Rechain {
        /// Function to create all memory structures `Mem` required to initialize the ledger object
        ///
        /// #### Usage example
        /// ```motoko
        ///     stable let chain_mem = rechain.Mem();
        /// ```
        public func new() : MU.MemShell<Mem> = MU.new<Mem>(
            {
            history = SWB.SlidingWindowBufferNewMem<Value>();
            var phash = null;
            var lastIndex = 0;
            var firstIndex = 0;
            archives = Map.new<Principal, TransactionRange>();
            cert_store = CertTree.newStore(); 
            eventlog_mem = SWB.SlidingWindowBufferNewMem<Text>();
            }
        );
        
        /// Type structure used to initialize a `Chain` object.
        ///
        /// #### Fields
        /// - `history` - stable structure to store the ledger.
        /// - `phash` - hash value of the last block pushed into the ledger.
        /// - `lastIndex` - index of the next block to be stored in the ledger (consecutive).
        /// - `firstIndex` - index of the first block available in the ledger (blocks previous to firstIndex block are archived).
        /// - `canister` - principal of the canister that owns this ledger.
        /// - `archives` - map storing refferences to all archive canisters.
        /// - `cert_store` - object storing all certificates generated so far (one certificate per stored block).
        /// - `eventlog_mem` - logging structure to store execution logs for post-mortem analysis.
        ///   
        public type Mem = {
            history : SWB.StableData<Value>;
            var phash : ?Blob;
            var lastIndex : Nat;
            var firstIndex : Nat;
            archives : Map.Map<Principal, TransactionRange>;
            cert_store : CertTree.Store;
            eventlog_mem : SWB.StableData<Text>;
        };

        public type ValueMap = (Text, Value);
        public type Value = { 
            #Blob : Blob; 
            #Text : Text; 
            #Nat : Nat;
            #Int : Int;
            #Array : [Value]; 
            #Map : [ValueMap]; 
        };

        public type TransactionRange = {
            start : Nat;
            length : Nat;
        };
    }
}
