import Array "mo:base/Array";
import Nat "mo:base/Nat";
import T "./types";
import Ver1 "./memory/no_archive/v1";
import MU "mo:mosup";

module {

  public module Mem {
    public module NoArchive {
      public let V1 = Ver1.NoArchive;
    };
  };
  let VM = Mem.NoArchive.V1;

  public type ActionReducer<A, B> = (A) -> ReducerResponse<B>;
  public type BlockId = Nat;
  public type ReducerResponse<E> = {
    #Ok : (BlockId) -> ();
    #Pass;
    #Err : E;
  };

  public type Transaction = T.Value;
  
  public class RechainNoArchive<A, E>({
    xmem : MU.MemShell<VM.Mem>;
    reducers : [ActionReducer<A, E>];
  }) {
    let mem = MU.access(xmem);
    
    public func dispatch(action : A) : ({ #Ok : BlockId; #Err : E }) {

      let reducerResponse = Array.map<ActionReducer<A, E>, ReducerResponse<E>>(reducers, func(fn) = fn(action));

      let hasError = Array.find<ReducerResponse<E>>(reducerResponse, func(resp) = switch (resp) { case (#Err(_)) true; case (_) false });

      switch (hasError) { case (? #Err(e)) { return #Err(e) }; case (_) () };
 
      let blockId = mem.lastIndex + 1; 
      
      ignore Array.map<ReducerResponse<E>, ()>(reducerResponse, func(resp) { let #Ok(f) = resp else return (); f(blockId) });
     
      mem.lastIndex := blockId;

      #Ok(blockId);
    };


  };
};
