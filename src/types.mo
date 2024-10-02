import SW "mo:stable-write-only";

module {
   
    public type ValueMap = (Text, Value);
    public type Value = { 
        #Blob : Blob; 
        #Text : Text; 
        #Nat : Nat;
        #Int : Int;
        #Array : [Value]; 
        #Map : [ValueMap]; 
    };

    public type ArchiveInitArgs = {
        maxRecords : Nat;
        maxPages : Nat;
        indexType : SW.IndexType;
        firstIndex : Nat;
    };

    public type AddTransactionsResponse = {
        #Full : SW.Stats;
        #ok : SW.Stats;
        #err: Text;
    };

    public type UpdatecontrollerResponse = {
        #ok : Nat;
        #err: Nat;
    };

    public type TransactionRange = {
        start : Nat;
        length : Nat;
    };

    public type Transaction = Value;

    public type BlockType = {
        block_type : Text;
        url : Text;
    };

    public type InitArgs = {
      maxActiveRecords : Nat;
      settleToRecords : Nat;
      maxRecordsInArchiveInstance : Nat;
      maxArchivePages : Nat;
      archiveIndexType : SW.IndexType;
      maxRecordsToArchive : Nat;
      archiveCycles : Nat;
      minArchiveCycles : Nat;
      secsCycleMaintenance : Nat;
      archiveControllers : [Principal];
      supportedBlocks : [BlockType];
    };


    public type canister_settings = {
        controllers : ?[Principal];
        freezing_threshold : ?Nat;
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };
    
    public type IC = actor {
        update_settings : shared {
            canister_id : Principal;
            settings : canister_settings;
        } -> async ();
    };

    public type Stats = {
        localLedgerSize : Nat;
        lastIndex: Nat;
        firstIndex: Nat;
        archives: [(Principal, TransactionRange)];
        ledgerCanister : ?Principal;
        bCleaning : Bool;
        archiveProperties: InitArgs;
    };
    
    public type GetBlocksArgs = [TransactionRange];
    
    public type GetTransactionsResult = {
        log_length : Nat;        
        blocks : [{ id : Nat; block : ?Value }];
        archived_blocks : [ArchivedTransactionResponse];
    };
    public type GetTransactionsFn = shared query ([TransactionRange]) -> async GetTransactionsResult;
    public type ArchivedTransactionResponse = {
        args : [TransactionRange];
        callback : GetTransactionsFn;
    };

    public type GetBlocksResult = GetTransactionsResult;
    
    public type GetArchivesArgs =  {
      from : ?Principal;
    };
    
    public type GetArchivesResult = [GetArchivesResultItem];

    public type GetArchivesResultItem = {

        canister_id : Principal;

        start : Nat;

        end : Nat;
    };

    public type ServiceBlock = { id : Nat; block: ?Value };

    public type TxIndex = Nat;

    public type TransactionsResult = {
      blocks: [Transaction];
    };

    public type DataCertificate =  {
        certificate : Blob;

        hash_tree : Blob;
    };

    public type ArchiveInterface = actor {

      append_transactions : shared ([Transaction]) -> async AddTransactionsResponse;

      total_transactions : shared query () -> async Nat;

      get_transaction : shared query (Nat) -> async ?Transaction;

      icrc3_get_blocks : shared query (TransactionRange) -> async TransactionsResult;

      remaining_capacity : shared query () -> async Nat;

      cycles : shared query () -> async Nat;

      deposit_cycles : shared () -> async ();
    };

    public type ICRC3Interface = actor {
        icrc3_get_blocks : GetTransactionsFn;
        icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult) ;
        icrc3_supported_block_types: query () -> async [BlockType];
  };
}