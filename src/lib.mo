import SWB "mo:swb/Stable";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";

module {

    public type BlockId = Nat;
    public type BlockSchemaId = Text;
    public type Block = (BlockSchemaId, Blob);

    public type GetTransactionsResponse = {
        first_index : Nat;
        log_length : Nat;
        transactions : [Block];
        archived_transactions : [ArchivedRange];
    };
    public type ArchivedRange = {
        callback : shared query GetBlocksRequest -> async TransactionRange;
        start : Nat;
        length : Nat;
    };
    public type TransactionRange = { transactions : [Block] };

    public type GetBlocksRequest = { start : Nat; length : Nat };

    // -- 

    public type Mem<A> = {
        history : SWB.StableData<Block>;
        var phash : Blob;
    };

    public func Mem<A>() : Mem<A> {
        {
            history = SWB.SlidingWindowBufferNewMem<Block>();
            var phash = Blob.fromArray([0]);
        }
    };

    public type ActionReducer<A,B> = (A) -> ReducerResponse<B>;

    public type ReducerResponse<E> = {
        #Ok: (BlockId) -> ();
        #Err : E
    };

    public class Chain<A,E,B>({
        mem: Mem<A>;
        encodeBlock: (B) -> Block;
        addPhash: (A, phash: Blob) -> B;
        hashBlock: (Block) -> Blob;
        reducers : [ActionReducer<A,E>];
        }) {
        let history = SWB.SlidingWindowBuffer<Block>(mem.history);

        public func dispatch( action: A ) : {#Ok : BlockId;  #Err: E } {

            // Execute reducers
            let reducerResponse = Array.map<ActionReducer<A,E>, ReducerResponse<E>>(reducers, func (fn) = fn(action));

            // Check if any reducer returned an error and terminate if so
            let hasError = Array.find<ReducerResponse<E>>(reducerResponse, func (resp) = switch(resp) { case(#Err(_)) true; case(_) false; });
            switch(hasError) { case (?#Err(e)) { return #Err(e)};  case (_) (); };

            let blockId = history.end() + 1;
            // Execute state changes if no errors
            ignore Array.map<ReducerResponse<E>, ()>(reducerResponse, func (resp) {let #Ok(f) = resp else return (); f(blockId);});

            // Add block to history
            let fblock = addPhash(action, mem.phash);
            let encodedBlock = encodeBlock(fblock);
            ignore history.add(encodedBlock);
            mem.phash := hashBlock(encodedBlock);

            #Ok(blockId);
        };

        // Handle transaction retrieval and archiving
        public func get_transactions(req: GetBlocksRequest) : GetTransactionsResponse {
            let length = Nat.min(req.length, 1000);
            let end = history.end();
            let start = history.start();
            let resp_length = Nat.min(length, end - start);
            let transactions = Array.tabulate<Block>(resp_length, func (i) {
                let ?block = history.getOpt(start + i) else Debug.trap("Internal error");
                block;
                }); 

            {
                first_index=start;
                log_length=end;
                transactions;
                archived_transactions = [];
            }
        };
    };


}