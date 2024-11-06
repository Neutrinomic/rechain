import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import rechain  "../src";
import Nat64 "mo:base/Nat64";
import Vector "mo:vector";
import Time "mo:base/Time";

actor class Delta({archive_controllers: [Principal]}) = this {

    public type Action = {
        ts: Nat64;
        created_at_time: Nat64;
        memo: Blob;
        caller: Principal;
        fee: Nat;
        payload : {
            #swap: {
                amt: Nat;
            };
            #add: {
                amt : Nat;
            };
        };
    };

    public type ActionError = {ok:Nat; err:Text};

    stable let chain_mem  = rechain.Mem.Rechain.V1.new();

    func encodeBlock(b: Action): ?[rechain.ValueMap] {
        ?[
            ("ts", #Nat(Nat64.toNat(b.ts))),
            ("btype", #Text(switch (b.payload) {
                    case (#swap(_)) "1swap";
                    case (#add(_)) "1add";
                })),
            ("tx", #Map([
                ("created_at_time", #Nat(Nat64.toNat(b.created_at_time))),
                ("memo", #Blob(b.memo)),
                ("caller", #Blob(Principal.toBlob(b.caller))),
                ("fee", #Nat(b.fee)),
                ("payload", #Map(switch (b.payload) {
                    case (#swap(data)) {
                        [
                            ("amt", #Nat(data.amt))
                        ]
                    };
                    case (#add(data)) {
                        [
                            ("amt", #Nat(data.amt))
                        ]
                    };
                }))
            ]))
        ];
    };

    var chain = rechain.Chain<system, Action, ActionError>({
        settings = ?{rechain.DEFAULT_SETTINGS with supportedBlocks = []; maxActiveRecords = 100; settleToRecords = 30; maxRecordsInArchiveInstance = 120; archiveControllers = archive_controllers};
        xmem = chain_mem;
        encodeBlock = encodeBlock;
        reducers = [];
        me_can = Principal.fromActor(this);
    });

    public query func icrc3_get_blocks(args: rechain.GetBlocksArgs): async rechain.GetBlocksResult {
        return chain.icrc3_get_blocks(args);
    };

    public query func icrc3_get_archives(args: rechain.GetArchivesArgs): async rechain.GetArchivesResult {
        return chain.icrc3_get_archives(args);
    };

    public query func icrc3_supported_block_types(): async [rechain.BlockType] {
        return chain.icrc3_supported_block_types();
    };

    
    public type DispatchResult = {#Ok: rechain.BlockId; #Err: ActionError };


    public func dispatch(actions: [Action]): async [DispatchResult] {
        let v = Vector.new<DispatchResult>();
        for (a in actions.vals()) {
            Vector.add(v, chain.dispatch(a));
        };
        Vector.toArray(v);
    };

    let canister_last_modified = Time.now();

    public query func last_modified(): async Time.Time {
        canister_last_modified;
    };

};