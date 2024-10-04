import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import SWB "mo:swbstable/Stable";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import CertifiedData "mo:base/CertifiedData";
import Error "mo:base/Error";
import T "./types";
import Vec "mo:vector";
import RepIndy "mo:rep-indy-hash";
import Text "mo:base/Text";
import Timer "mo:base/Timer";
import Archive "./archive";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import CertTree "mo:ic-certification/CertTree";
import MTree "mo:ic-certification/MerkleTree";
import Option "mo:base/Option";
import Utils "./utils";
import SysLog "./syslog";

module {

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
    history : SWB.StableData<T.Value>;
    var phash : ?Blob;
    var lastIndex : Nat;
    var firstIndex : Nat;
    var canister : ?Principal;
    archives : Map.Map<Principal, T.TransactionRange>;
    cert_store : CertTree.Store;
    eventlog_mem : SWB.StableData<Text>;
  };

  /// Function to create all memory structures `Mem` required to initialize the ledger object
  ///
  /// #### Usage example
  /// ```motoko
  ///     stable let chain_mem = rechain.Mem();
  /// ```
  public func Mem() : Mem {
    {
      history = SWB.SlidingWindowBufferNewMem<T.Value>();
      var phash = null;
      var lastIndex = 0;
      var firstIndex = 0;
      var canister = null;
      archives = Map.new<Principal, T.TransactionRange>();
      cert_store = CertTree.newStore(); 
      eventlog_mem = SWB.SlidingWindowBufferNewMem<Text>();
    };
  };

  /// ICRC3 block type defintion 
  ///
  public type Value = T.Value;
  public type ValueMap = T.ValueMap;

  public type GetBlocksArgs = T.GetBlocksArgs;
  public type GetBlocksResult = T.GetBlocksResult;
  public type GetArchivesArgs = T.GetArchivesArgs;
  public type GetArchivesResult = T.GetArchivesResult;
  public type ActionReducer<A, B> = (A) -> ReducerResponse<B>;
  public type BlockId = Nat;
  public type Stats = T.Stats;
  public type ReducerResponse<E> = {
    #Ok : (BlockId) -> ();
    #Pass;
    #Err : E;
  };

  public type Transaction = T.Value;
  public type AddTransactionsResponse = T.AddTransactionsResponse;
  public type BlockType = T.BlockType;
  
  /// Default settings to initialize a `Chain` object. 
  ///
  /// #### Fields
  /// - `maxActiveRecords` - maximum size of ledger before archiving (2000).
  /// - `settleToRecords` - ledger size after archiving (1000).
  /// - `maxRecordsInArchiveInstance` - maximum sixe of archive canister. If archive is full, we create a new one (10_000_000).
  /// - `maxArchivePages` - every page is 65536 per KiB. 62500 pages is default size (4 Gbytes).
  /// - `archiveIndexType` - archive canister memory are always of `#stable` type.
  /// - `maxRecordsToArchive` - maximum number of blocks archived every archiving cycle (10_000)
  /// - `archiveCycles` - cycle requirement to create an archive canister (2T: 2_000_000_000).
  /// - `minArchiveCycles` - if archive canister is below this balance (and main ledger canister balance is > 2*archiveCycles) we add "archiveCycles" (500_000_000_000).
  /// - `secsCycleMaintenance` - every time period we check whether archive canisters have enough cycles (6 hours: 21600);
  /// - `archiveControllers` - additional archive canisters controllers if any (default is empty).
  /// - `supportedBlocks` - not yet implemented (default is empty).
  public let DEFAULT_SETTINGS = {
    maxActiveRecords = 2000; 
    settleToRecords = 1000; 
    maxRecordsInArchiveInstance = 10_000_000; 
    maxArchivePages = 62500; 
    archiveIndexType = #Stable;
    maxRecordsToArchive = 10_000; 
    archiveCycles = 2_000_000_000_000; 
    minArchiveCycles = 500_000_000_000; 
    secsCycleMaintenance = 21600; 
    archiveControllers = [];
    supportedBlocks = [];
  } : T.ChainSettings;


  /// Class `Chain`.
  ///
  /// #### Fields
  /// - `mem` - stable structure of type `Mem`.
  /// - `encodeBlock` - custom function to encode user application specific events into ICRC3 `Value` type object.
  /// - `reducers` - list of reducer functions meant to update the canister state with every canister event.
  /// - `settings` - initialization arguments.
  ///
  /// #### Initilization example
  /// ```motoko
  ///     func encodeBlock(b: UserAction) : ?[ValueMap] {...}
  ///     stable let balances_mem = Balances.Mem();
  ///     let balances = Balances.Balances({
  ///         config;
  ///         mem = balances_mem;
  ///     });
  ///     stable let chain_mem = rechain.Mem();     
  ///     var chain = rechain.Chain<T.Action, T.ActionError>({ 
  ///                     settings = ?{rechain.DEFAULT_SETTINGS with 
  ///                                  supportedBlocks = []; 
  ///                                  maxActiveRecords = 100; // testing purposes
  ///                                  settleToRecords = 30; 
  ///                                  maxRecordsInArchiveInstance = 120;
  ///                                 };
  ///                     mem = chain_mem;         
  ///                     encodeBlock = encodeBlock;
  ///                     reducers = [balances.reducer]; 
  ///                });
  /// ```
  public class Chain<A, E>({
    mem : Mem;
    encodeBlock : (A) -> ?[T.ValueMap];
    reducers : [ActionReducer<A, E>];
    settings : ?T.ChainSettings;
  }) {

    var started = false;

    let history = SWB.SlidingWindowBuffer<T.Value>(mem.history);

    let archiveState = {
      var bCleaning = false; 
      var cleaningTimer : ?Nat = null; 
      settings = Option.get(settings, DEFAULT_SETTINGS);
   
    };

    /// Main method of `Chain` object. It Sends the canister action to the the reducers to update the canister state,
    /// it calls the `encodeBlock` method, and finally pushes the encoded block into the ledger
    ///
    /// #### Usage example
    /// ```motoko
    ///     // User canister update method
    ///     public shared(msg) func add_record(x: Action): async (DispatchResult) {
    ///        let ret = chain.dispatch(x); 
    ///        return ret;
    ///     };
    /// ```
    public func dispatch(action : A) : ({ #Ok : BlockId; #Err : E }) {
      let reducerResponse = Array.map<ActionReducer<A, E>, ReducerResponse<E>>(reducers, func(fn) = fn(action));
      let hasError = Array.find<ReducerResponse<E>>(reducerResponse, func(resp) = switch (resp) { case (#Err(_)) true; case (_) false });

      switch (hasError) { case (? #Err(e)) { return #Err(e) }; case (_) () };
      
      let blockId = mem.lastIndex + 1; 
 
      ignore Array.map<ReducerResponse<E>, ()>(reducerResponse, func(resp) { let #Ok(f) = resp else return (); f(blockId) });

      let encodedBlock: ?[T.ValueMap] = encodeBlock(action); 

      switch (encodedBlock) {
        case (null) {};
        case (?aux) {
          let encodedBlock_nonull: [T.ValueMap] = aux;
          let trx = Vec.new<T.ValueMap>();
          ignore do ? {Vec.add(trx, ("phash", #Blob(mem.phash!)))};
      
          Vec.addFromIter(trx, encodedBlock_nonull.vals());
   
          let thisTrx = #Map(Vec.toArray(trx));
          mem.phash := ?Blob.fromArray(RepIndy.hash_val(thisTrx));
          ignore history.add(thisTrx);
        };
      };

      mem.lastIndex := mem.lastIndex + 1;
      dispatch_cert();

      #Ok(blockId);
    };

    public func upgrade_archives() : async () {

      for (archivePrincipal in Map.keys(mem.archives)) {
        let archiveActor = actor (Principal.toText(archivePrincipal)) : T.ArchiveInterface;
        let ArchiveMgr = (system Archive.archive)(#upgrade archiveActor);
        ignore await ArchiveMgr(null); // No change in settings
      };
    };

    private func new_archive<system>(initArg : T.ArchiveInitArgs) : async ?(actor {}) {
      
      let ?this_canister = mem.canister else Debug.trap("No canister set");

      if (ExperimentalCycles.balance() > archiveState.settings.archiveCycles * 2) {
        ExperimentalCycles.add<system>(archiveState.settings.archiveCycles);
      } else { 
        Debug.print("Not enough cycles" # debug_show (ExperimentalCycles.balance()));
        archiveState.bCleaning := false;
        return null;
      };

      let ArchiveMgr = (system Archive.archive)(
        #new {
          settings = ?{
            controllers = ?Array.append([this_canister], archiveState.settings.archiveControllers);
            compute_allocation = null;
            memory_allocation = null;
            freezing_threshold = null;
          };
        }
      );

      try {
        return ?(await ArchiveMgr(?initArg));
      } catch (err) {
        archiveState.bCleaning := false;
        Debug.print("Error creating archive canister " # Error.message(err));
        return null;
      };

    };

    private func dispatch_cert() : () {
      let ?latest_hash = mem.phash else return;

      let ct = CertTree.Ops(mem.cert_store);
      ct.put([Text.encodeUtf8("last_block_index")], Utils.encodeBigEndian(mem.lastIndex));//Blob.fromArray(fromNat(mem.lastIndex,10)));//Utils.encodeBigEndian(mem.lastIndex));
      ct.put([Text.encodeUtf8("last_block_hash")], latest_hash);
      ct.setCertifiedData();
    };


    private func check_clean_up<system>() : async () {
      if (not started) return;

      archiveState.cleaningTimer := null;

      if (archiveState.bCleaning) {
      };

      if (history.len() < archiveState.settings.maxActiveRecords) {
        return;
      };
      
      let archives = Iter.toArray(Map.entries<Principal, T.TransactionRange>(mem.archives));

      archiveState.bCleaning := true;

      let (archive_detail, available_capacity) = if (Map.size(mem.archives) == 0) {
       
        let ?newArchive = await new_archive<system>({
          maxRecords = archiveState.settings.maxRecordsInArchiveInstance;
          indexType = archiveState.settings.archiveIndexType;
          maxPages = archiveState.settings.maxArchivePages;
          firstIndex = 0;
        }) else {
          return;
        };

        let newItem = {
          start = 0;
          length = 0;
        };

        ignore Map.put<Principal, T.TransactionRange>(mem.archives, Map.phash, Principal.fromActor(newArchive), newItem);
        ((Principal.fromActor(newArchive), newItem), archiveState.settings.maxRecordsInArchiveInstance);
      } else {
        let lastArchive = switch (Map.peek(mem.archives)) {
          case (null) { Debug.trap("mem.archives unreachable") }; 
          case (?val) val;
        };
        if (lastArchive.1.length >= archiveState.settings.maxRecordsInArchiveInstance) {

          let ?newArchive = await new_archive({
            maxRecords = archiveState.settings.maxRecordsInArchiveInstance;
            indexType = archiveState.settings.archiveIndexType;
            maxPages = archiveState.settings.maxArchivePages;
            firstIndex = lastArchive.1.start + lastArchive.1.length;
          }) else return;

          let newItem = {
            start = mem.firstIndex;
            length = 0;
          };
          ignore Map.put(mem.archives, Map.phash, Principal.fromActor(newArchive), newItem);
          ((Principal.fromActor(newArchive), newItem), archiveState.settings.maxRecordsInArchiveInstance);
        } else {
          let capacity = if (archiveState.settings.maxRecordsInArchiveInstance >= lastArchive.1.length) {
            Nat.sub(archiveState.settings.maxRecordsInArchiveInstance, lastArchive.1.length);
          } else {
            Debug.trap("max archive lenghth must be larger than the last archive length");
          };

          (lastArchive, capacity);
        };
      };

      let archive = actor (Principal.toText(archive_detail.0)) : T.ArchiveInterface;

      var archive_amount = if (history.len() > archiveState.settings.settleToRecords) {
        Nat.sub(history.len(), archiveState.settings.settleToRecords);
      } else {
        Debug.trap("Settle to records must be equal or smaller than the size of the ledger upon clanup");

      };

      var bRecallAtEnd = false;

      if (archive_amount > available_capacity) {
        bRecallAtEnd := true;
        archive_amount := available_capacity;
      };

      if (archive_amount > archiveState.settings.maxRecordsToArchive) {
        bRecallAtEnd := true;
        archive_amount := archiveState.settings.maxRecordsToArchive;
      };

      let length = Nat.min(history.len(), 1000);
      let end = history.end();
      let start = history.start();
      let resp_length = Nat.min(length, end - start);
      let toArchive = Vec.new<Transaction>();
      let transactions_array = Array.tabulate<T.Value>(
        resp_length,
        func(i) {
          let ?block = history.getOpt(start + i) else Debug.trap("Internal error");
          block;
        },
      );
      label find for (thisItem in Array.vals(transactions_array)) {
        Vec.add(toArchive, thisItem);
        if (Vec.size(toArchive) == archive_amount) break find;
      };

      try {
        let result = await archive.append_transactions(Vec.toArray(toArchive));
        let stats = switch (result) {
          case (#ok(stats)) stats;
          case (#Full(stats)) stats;
          case (#err(_)) {
            archiveState.bCleaning := false; 
            return;
          };
        };

        let archivedAmount = Vec.size(toArchive);

        history.deleteTo(mem.firstIndex + archivedAmount);
        mem.firstIndex := mem.firstIndex + archivedAmount;

        ignore Map.put(
          mem.archives,
          Map.phash,
          Principal.fromActor(archive),
          {
            start = archive_detail.1.start;
            length = archive_detail.1.length + archivedAmount;
          },
        );
      } catch (_) {
        archiveState.bCleaning := false;
        return;
      };
      archiveState.bCleaning := false;

      return;
    };

    /// this method is used to start the recurrent timers in charge of 1) archive creation, 2) cycle replenishment.
    ///
    /// #### Usage example
    /// ```motoko
    ///     // The following code is called in the main body of the user canister
    ///     ignore Timer.setTimer<system>(#seconds 0, func () : async () {
    ///           await chain.start_timers<system>();
    ///     });
    /// ```
    public func start_timers<system>() : async () {
      if (started) Debug.trap("already started");
      started := true;
      
      ignore Timer.recurringTimer<system>(#seconds 30, check_clean_up);
      ignore Timer.recurringTimer<system>(#seconds(archiveState.settings.secsCycleMaintenance), archiveCycleMaintenance);
    };

    public func stop_timers() {
      started := false;
    };

    private func archiveCycleMaintenance<system>() : async () {
      if (not started) return;
      
      let syslog = SysLog.SysLog({_eventlog_mem=mem.eventlog_mem});
      let archives = Iter.toArray(Map.entries<Principal, T.TransactionRange>(mem.archives));
     
      for (i in archives.keys()) {
        let (a,_) = archives[i];
        try {
          let archiveActor = actor (Principal.toText(a)) : T.ArchiveInterface;        
          let archive_cycles : Nat = await archiveActor.cycles();
              
          if (archive_cycles < archiveState.settings.minArchiveCycles) {
            if (ExperimentalCycles.balance() > archiveState.settings.archiveCycles * 2) { 
              
              let refill_amount = archiveState.settings.archiveCycles;
              try{
                ExperimentalCycles.add<system>(refill_amount);
                await archiveActor.deposit_cycles();
              } catch (err) {
                syslog.add("Err : Failed to refill " # Principal.toText(a) # " width " # debug_show(refill_amount) # " : " # Error.message(err));
              };
            } else { 
              Debug.print("Err : Not enough cycles to replenish archive canisters " # debug_show (ExperimentalCycles.balance()));
            };
          };
        }
        catch(err) {
          syslog.add("Err : Failed to get canister " # Principal.toText(a) # " : " # Error.message(err));
        };
      };
    };

    public func stats() : T.Stats {
      return {
        localLedgerSize = history.len(); 
        lastIndex = mem.lastIndex;
        firstIndex = mem.firstIndex;
        archives = Iter.toArray(Map.entries<Principal, T.TransactionRange>(mem.archives));
        ledgerCanister = mem.canister;
        bCleaning = archiveState.bCleaning;
        archiveProperties = archiveState.settings;
      };
    };
    
    /// implements the ICRC3 standard query call to retrieve blocks.
    ///
    /// #### Standard refference
    /// https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-3/README.md#icrc3_get_blocks
    public func icrc3_get_blocks(args : T.GetBlocksArgs) : T.GetBlocksResult {
      let local_ledger_length = history.len();
      let ledger_length = if (mem.lastIndex == 0 and local_ledger_length == 0) {
        0;
      } else {
        mem.lastIndex; 
      };

      let transactions = Vec.new<T.ServiceBlock>();

      for (thisArg in args.vals()) {
        let start = if (thisArg.start + thisArg.length > mem.firstIndex) {

          let start = if (thisArg.start <= mem.firstIndex) {
            mem.firstIndex; 
          } else {
            if (thisArg.start >= (mem.firstIndex)) {
              thisArg.start;
            } else {
              Debug.trap("last index must be larger than requested start plus one");
            };
          };

          let end = if (history.len() == 0) {
            mem.lastIndex; 
          } else if (thisArg.start + thisArg.length >= mem.lastIndex) {
            mem.lastIndex - 1 : Nat; 
          } else {
            thisArg.start + thisArg.length - 1 : Nat;
          };

          if (history.len() > 0) {
            label search for (thisItem in Iter.range(start, end)) {
              if (thisItem >= mem.lastIndex) {
                break search;
              };
              Vec.add(
                transactions,
                {
                  id = thisItem; 
                  block = history.getOpt(thisItem);
                },
              );
            };
          };
        };
      };

      let archives = Map.new<Principal, (Vec.Vector<T.TransactionRange>, T.GetTransactionsFn)>();

      for (thisArgs in args.vals()) {
        if (thisArgs.start < mem.firstIndex) {

          var seeking = thisArgs.start;
          label archive for (thisItem in Map.entries(mem.archives)) {
            if (seeking > Nat.sub(thisItem.1.start + thisItem.1.length, 1) or thisArgs.start + thisArgs.length <= thisItem.1.start) {
              continue archive;
            };

            let overlapStart = Nat.max(seeking, thisItem.1.start);
            let overlapEnd = Nat.min(thisArgs.start + thisArgs.length - 1, thisItem.1.start + thisItem.1.length - 1);
            let overlapLength = Nat.sub(overlapEnd, overlapStart) + 1;

            switch (Map.get(archives, Map.phash, thisItem.0)) {
              case (null) {
                let newVec = Vec.new<T.TransactionRange>();
                Vec.add(
                  newVec,
                  {
                    start = overlapStart;
                    length = overlapLength;
                  },
                );
                let fn : T.GetTransactionsFn = (actor (Principal.toText(thisItem.0)) : T.ICRC3Interface).icrc3_get_blocks;
                ignore Map.put<Principal, (Vec.Vector<T.TransactionRange>, T.GetTransactionsFn)>(archives, Map.phash, thisItem.0, (newVec, fn));
              };
              case (?existing) {
                Vec.add(
                  existing.0,
                  {
                    start = overlapStart;
                    length = overlapLength;
                  },
                );
              };
            };

            if (overlapEnd == Nat.sub(thisArgs.start + thisArgs.length, 1)) {
              break archive;
            };

            seeking := overlapEnd + 1;
          };
        };
      };

      return {
        log_length = ledger_length;
        certificate = CertifiedData.getCertificate(); 
        blocks = Vec.toArray(transactions);
        archived_blocks = Iter.toArray<T.ArchivedTransactionResponse>(
          Iter.map<(Vec.Vector<T.TransactionRange>, T.GetTransactionsFn), T.ArchivedTransactionResponse>(
            Map.vals(archives),
            func(x : (Vec.Vector<T.TransactionRange>, T.GetTransactionsFn)) : T.ArchivedTransactionResponse {
              {
                args = Vec.toArray(x.0);
                callback = x.1;
              };
            },
          )
        );
      };
    };

    /// implements the ICRC3 standard query call to retrieve archive canister information holding different ranges of blocks specified in `request`.
    /// this method is not part of the ICRC3 standard.
    public func icrc3_get_archives(request : T.GetArchivesArgs) : T.GetArchivesResult {

      let ?canister_aux = mem.canister else Debug.trap("Archive controller canister must be set before call get_archives");
       
      let results = Vec.new<T.GetArchivesResultItem>();

      var bFound = switch (request.from) {
        case (null) true;
        case (?Principal) false;
      };
      if (bFound == true) {
        Vec.add(
          results,
          {
            canister_id = canister_aux;
            start = mem.firstIndex;
            end = mem.lastIndex;
          },
        );
      } else {
        switch (request.from) {
          case (null) {}; 
          case (?val) {
            if (canister_aux == val) {
              bFound := true;
            };
          };
        };
      };

      for (thisItem in Map.entries<Principal, T.TransactionRange>(mem.archives)) {
        if (bFound == true) {
          if (thisItem.1.start + thisItem.1.length >= 1) {
            Vec.add(
              results,
              {
                canister_id = (thisItem.0);
                start = thisItem.1.start;
                end = Nat.sub(thisItem.1.start + thisItem.1.length, 1);
              },
            );
          } else {
            Debug.trap("found archive with length of 0");
          };
        } else {
          switch (request.from) {
            case (null) {}; 
            case (?val) {
              if (thisItem.0 == val) {
                bFound := true;
              };
            };
          };
        };
      };

      return Vec.toArray(results);
    };

    /// implements the ICRC3 standard query call to retrieve the certificate of the last block added to the ledger.
    ///
    /// #### Standard refference
    /// https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-3/README.md#icrc3_get_tip_certificate
    public func icrc3_get_tip_certificate() : ?T.DataCertificate {

      let ct = CertTree.Ops(mem.cert_store);
      let blockWitness = ct.reveal([Text.encodeUtf8("last_block_index")]);
      let hashWitness = ct.reveal([Text.encodeUtf8("last_block_hash")]);
      let merge = MTree.merge(blockWitness, hashWitness);
      let witness = ct.encodeWitness(merge);

      do ? {{
        certificate = CertifiedData.getCertificate()!;
        hash_tree = witness;
      }};

    };

    public func icrc3_supported_block_types() : [T.BlockType] {
      return archiveState.settings.supportedBlocks;
    }

  };
};