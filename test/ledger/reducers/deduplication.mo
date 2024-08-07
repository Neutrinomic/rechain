import Map "mo:map/Map";
import Result "mo:base/Result";
import Sha256 "mo:sha2/Sha256";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Chain "../../../src/lib";
import U "../utils";
import T "../types";

module {
    
    public type Mem = {
        dedup : Map.Map<Blob, Nat>;
    };

    public func Mem() : Mem {
        {
            dedup = Map.new<Blob, Nat>();
        }
    };

    public class Deduplication({mem: Mem; config:T.Config}) {
  
        public func reducer(action: T.Action) : Chain.ReducerResponse<T.ActionError> {

            ignore do ? { if (action.ts < action.created_at_time!) return #Err(#CreatedInFuture({ledger_time = action.ts}))};
            ignore do ? { if (action.created_at_time! + config.TX_WINDOW + config.PERMITTED_DRIFT < action.ts) return #Err(#TooOld)};

            let dedupId = dedupIdentifier(action);
            ignore do ? { return #Err(#Duplicate({duplicate_of=Map.get(mem.dedup, Map.bhash, dedupId!)!})); };

            #Ok(func(blockId) {
                ignore do ? { Map.put(mem.dedup, Map.bhash, dedupId!, blockId); };
                });
        };
        
        private func dedupIdentifier(action: T.Action) : ?Blob {
            do ? {
                let memo = action.memo!;
                let created_at = action.created_at_time!;
                let digest = Sha256.Digest(#sha224);
                digest.writeBlob(Principal.toBlob(action.caller));
                digest.writeArray(U.ENat64(created_at));
                digest.writeBlob(memo);
                digest.sum();
            }
        };
    };
}