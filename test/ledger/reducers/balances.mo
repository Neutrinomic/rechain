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
import ICRC "../icrc";
import T "../types";

module {

    public type Mem = {
        accounts : Map.Map<Blob, Nat>;
    };

    public func Mem() : Mem = {
        accounts = Map.new<Blob, Nat>();
    };

    public class Balances({ mem : Mem; config:T.Config }) {   //<---

        public func reducer(action : T.Action) : Chain.ReducerResponse<T.ActionError> {

            switch(action.payload) {
                case (#transfer(p)) { 
                    let fee = switch (action.fee) {
                        case null 0;
                        case (?Nat) Nat;
                    }; 
                    
                    ignore do ? { if (fee != config.FEE) return #Err(#BadFee({ expected_fee = config.FEE })); };
                    
                    let from_principal_blob = p.from[0];
                
                    let from_subaccount_blob = if(p.from.size() > 1) p.from[1] else Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
                    let from_principal_principal = Principal.fromBlob(from_principal_blob);
                    let from_bacc = Principal.toLedgerAccount(from_principal_principal, ?from_subaccount_blob) 
                        else return #Err(#GenericError({ message = "Invalid From Subaccount"; error_code = 1111 }));
              
                    let to_principal_blob = p.to[0];
        
                    let to_subaccount_blob = if(p.to.size() > 1) p.to[1] else Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
                    let to_principal_principal = Principal.fromBlob(to_principal_blob);
                    
                    let to_bacc = Principal.toLedgerAccount(to_principal_principal, ?to_subaccount_blob) 
                        else return #Err(#GenericError({ message = "Invalid To Subaccount"; error_code = 1112 }));
                          
                    let bal = get_balance(from_bacc);
                    let to_bal = get_balance(to_bacc);
                    if (bal < p.amt + config.FEE) return #Err(#InsufficientFunds({ balance = bal }));
                    #Ok(
                        func(_) {
                            put_balance(from_bacc, bal - p.amt - config.FEE);
                            put_balance(to_bacc, to_bal + p.amt);
                        }
                    );
                };
                case (#transfer_from(p)) { 
                    #Ok(func(_){});    
                };
                case (#burn(p)) {
                              
                    let from_principal_blob = p.from[0];
               
                    let from_subaccount_blob = if(p.from.size() > 1) p.from[1] else Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
              
                    let from_principal_principal = Principal.fromBlob(from_principal_blob);

                    let from_bacc = Principal.toLedgerAccount(from_principal_principal, ?from_subaccount_blob) 
                        else return #Err(#GenericError({ message = "Invalid From Subaccount"; error_code = 1111 }));
             
                    let bal = get_balance(from_bacc);
     
                    if (bal < p.amt + config.FEE) return #Err(#BadBurn({ min_burn_amount = config.FEE }));
        
                    #Ok(
                        func(_) {
                            put_balance(from_bacc, bal - p.amt - config.FEE);
                        }
                    );
                };
                case (#mint(p)) {

                    let to_principal_blob = p.to[0];

                    let to_subaccount_blob = if(p.to.size() > 1) p.to[1] else Blob.fromArray([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);

                    let to_principal_principal = Principal.fromBlob(to_principal_blob);
                    let to_bacc = Principal.toLedgerAccount(to_principal_principal, ?to_subaccount_blob) 
                        else return #Err(#GenericError({ message = "Invalid To Subaccount"; error_code = 1112 }));
  
                    let to_bal = get_balance(to_bacc);
                    #Ok(
                        func(_) {
                            put_balance(to_bacc, to_bal + p.amt);
                        }
                    );
                }; 
            };

        };

        public func get(account: ICRC.Account) : Nat {
            let ?bacc = accountToBlob(account) else return 0;
            get_balance(bacc);
        };

        private func get_balance(bacc: Blob) : Nat {
            let ?bal = Map.get(mem.accounts, Map.bhash, bacc) else return 0;
            bal;
        };

        private func put_balance(bacc : Blob, bal : Nat) : () {
            ignore Map.put<Blob, Nat>(mem.accounts, Map.bhash, bacc, bal);
        };

        private func accountToBlob(acc: ICRC.Account) : ?Blob {
        ignore do ? { if (acc.subaccount!.size() != 32) return null; };
        ?Principal.toLedgerAccount(acc.owner, acc.subaccount);
    };
    };

};
