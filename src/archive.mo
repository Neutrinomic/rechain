import SW "mo:stable-write-only"; 
import T "./types";   
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Vec "mo:vector";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";

shared ({ caller = ledger_canister_id }) actor class archive (_args : ?T.ArchiveInitArgs) = this {

  let canister_last_modified = Time.now();

  type Transaction = T.Value;
  type MemoryBlock = {
      offset : Nat64;
      size : Nat;
  };

  public type InitArgs = T.ArchiveInitArgs;
 
  public type AddTransactionsResponse = T.AddTransactionsResponse;

  public type TransactionRange = T.TransactionRange;
  
  stable var args = switch(_args) { case (?a) { a }; case(null) { 
    
    Debug.trap("No args provided") } };
 
  stable var memstore = SW.init({
      maxRecords = args.maxRecords;
      indexType = args.indexType;
      maxPages = Nat64.fromNat(args.maxPages);
  });

  let sw = SW.StableWriteOnly(?memstore);

  public shared ({ caller }) func append_transactions(txs : [Transaction]) : async AddTransactionsResponse {


    if (caller != ledger_canister_id) {
        return #err("Unauthorized Access: Only the ledger canister can access this archive canister");
    };

    label addrecs for(thisItem in txs.vals()){
      let stats = sw.stats();
      if(stats.itemCount >= args.maxRecords){
        break addrecs;
      };
      ignore sw.write(to_candid(thisItem));
    };

    let final_stats = sw.stats();
    if(final_stats.itemCount >= args.maxRecords){
      return #Full(final_stats);
    };
    #ok(final_stats);
  };

  func total_txs() : Nat {
    sw.stats().itemCount;
  };

  public shared query func total_transactions() : async Nat {
      total_txs();
  };

  public shared query func get_transaction(tx_index : T.TxIndex) : async ?Transaction {
      return _get_transaction(tx_index);
  };

  private func _get_transaction(tx_index : T.TxIndex) : ?Transaction {
      let stats = sw.stats();
      
      let target_index =  if(tx_index >= args.firstIndex) Nat.sub(tx_index, args.firstIndex) else Debug.trap("Not on this canister requested " # Nat.toText(tx_index) # "first index: " # Nat.toText(args.firstIndex));
      if(target_index >= stats.itemCount) Debug.trap("requested an item outside of this archive canister. first index: " # Nat.toText(args.firstIndex) # " last item" # Nat.toText(args.firstIndex + stats.itemCount - 1));
      let t = from_candid(sw.read(target_index)) : ?Transaction;
      return t;
  };

  public shared query func icrc3_get_blocks(req : [T.TransactionRange]) : async T.GetTransactionsResult {

    let transactions = Vec.new<{id:Nat; block: ?Transaction}>();
    for(thisArg in req.vals()){
      var tracker = thisArg.start;
      for(thisItem in Iter.range(thisArg.start, thisArg.start + thisArg.length - 1)){
        switch(_get_transaction(thisItem)){
          case(null){
            //should be unreachable...do we return an error?
          };
          case(?val){
            var aux: ?(T.Value) = ?val;
            Vec.add(transactions, {id = tracker; block = ?val});
          };
        };
        tracker += 1;
      };
    };

    { 
      blocks = Vec.toArray(transactions);
      archived_blocks = [];
      log_length =  0;
      certificate = null;
    };
 
  };

  public shared query func remaining_capacity() : async Nat {
      args.maxRecords - sw.stats().itemCount;
  };

  public shared func deposit_cycles() : async () {
      let amount = ExperimentalCycles.available();
      let accepted = ExperimentalCycles.accept<system>(amount);
      assert (accepted == amount);
  };

  public query func cycles() : async Nat {
      ExperimentalCycles.balance();
  };

  public query func last_modified(): async Time.Time {
    canister_last_modified;
  };

};