import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import T "./types";
import Text "mo:base/Text";
import Timer "mo:base/Timer";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Utils "./utils";
import Nat8 "mo:base/Nat8";

module {

  public type Mem = {
    var lastIndex : Nat;
  };

  public func Mem() : Mem {
    {
      var lastIndex = 0;
    };
  };

  public type ActionReducer<A, B> = (A) -> ReducerResponse<B>;
  public type BlockId = Nat;
  public type ReducerResponse<E> = {
    #Ok : (BlockId) -> ();
    #Pass;
    #Err : E;
  };

  public type Transaction = T.Value;
  
  public class RechainNoArchive<A, E>({
    mem : Mem;
    reducers : [ActionReducer<A, E>];
  }) {

    public func dispatch(action : A) : ({ #Ok : BlockId; #Err : E }) {
      // Execute reducers
      let reducerResponse = Array.map<ActionReducer<A, E>, ReducerResponse<E>>(reducers, func(fn) = fn(action));
      // Check if any reducer returned an error and terminate if so
      let hasError = Array.find<ReducerResponse<E>>(reducerResponse, func(resp) = switch (resp) { case (#Err(_)) true; case (_) false });

      switch (hasError) { case (? #Err(e)) { return #Err(e) }; case (_) () };
      let blockId = mem.lastIndex + 1; //archiveState.history.end() + 1; // ILDE: now archiveState.lastIndex is the id of last block in the ledger
      // Execute state changes if no errors
      ignore Array.map<ReducerResponse<E>, ()>(reducerResponse, func(resp) { let #Ok(f) = resp else return (); f(blockId) });

      mem.lastIndex := blockId;

      #Ok(blockId);
    };


  };
};
