
import SW "mo:stable-write-only"; // ILDE: I have to add mops.toml

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

    //ILDEbegin
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

    /// The type to request a range of transactions from the ledger canister
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
        //supportedBlocks: [BlockType]; 
        ledgerCanister : ?Principal;
        bCleaning : Bool;
        archiveProperties: InitArgs;
    };
    
    public type GetBlocksArgs = [TransactionRange];
    
    public type GetTransactionsResult = {
        // Total number of transactions in the
        // transaction log
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
    // The last archive seen by the client.
    // The Ledger will return archives coming
    // after this one if set, otherwise it
    // will return the first archives.
      from : ?Principal;
    };
    
    public type GetArchivesResult = [GetArchivesResultItem];

    public type GetArchivesResultItem = {
        // The id of the archive
        canister_id : Principal;

        // The first block in the archive
        start : Nat;

        // The last block in the archive
        end : Nat;
    };

    public type ServiceBlock = { id : Nat; block: ?Value };

    public type TxIndex = Nat;

    public type TransactionsResult = {
      blocks: [Transaction];
    };

    public type DataCertificate =  {
        // See https://internetcomputer.org/docs/current/references/ic-interface-spec#certification
        certificate : Blob;

        // CBOR encoded hash_tree
        hash_tree : Blob;
    };

    public type ArchiveInterface = actor {
      /// Appends the given transactions to the archive.
      /// > Only the Ledger canister is allowed to call this method
      append_transactions : shared ([Transaction]) -> async AddTransactionsResponse;

      /// Returns the total number of transactions stored in the archive
      total_transactions : shared query () -> async Nat;

      /// Returns the transaction at the given index
      get_transaction : shared query (Nat) -> async ?Transaction;

      /// Returns the transactions in the given range
      icrc3_get_blocks : shared query (TransactionRange) -> async TransactionsResult;

      /// Returns the number of bytes left in the archive before it is full
      /// > The capacity of the archive canister is 32GB
      remaining_capacity : shared query () -> async Nat;

      cycles : shared query () -> async Nat;

      deposit_cycles : shared () -> async ();
    };

    public type ICRC3Interface = actor {
        icrc3_get_blocks : GetTransactionsFn;
        icrc3_get_archives : query (GetArchivesArgs) -> async (GetArchivesResult) ;
        //icrc3_get_tip_certificate : query () -> async (?DataCertificate);
        icrc3_supported_block_types: query () -> async [BlockType];
  };
}