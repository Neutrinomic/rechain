import { Principal } from "@dfinity/principal";
import { resolve } from "node:path";
import { Actor, PocketIc, createIdentity} from "@hadronous/pic";

import { IDL } from "@dfinity/candid";
import {
  _SERVICE as TestService,
  idlFactory as TestIdlFactory,
  init,
} from "./build/ledger.idl.js";

import {
  Action,
  Account,
  GetBlocksArgs,
  TransactionRange,
  GetTransactionsResult,
  Value,
} from "./build/ledger.idl.js";


// ILDE import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
//@ts-ignore
import { toState } from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

const WASM_PATH = resolve(__dirname, "./build/ledger.wasm");

export async function TestCan(pic: PocketIc, ledgerCanisterId: Principal) {
  const fixture = await pic.setupCanister<TestService>({
    idlFactory: TestIdlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(init({ IDL }), []), //{ ledgerId: ledgerCanisterId }
  });

  return fixture;
}

// function decodeBlock(my_blocks:GetTransactionsResult, block_pos:number ) {
//   // console.log(my_blocks.blocks[0]);
//   let my_block_id = -1n;
//   let my_block_ts = -1n;
//   let my_created_at_time = -1n;
//   let my_memo;//: Uint8Array | number[];
//   let my_caller;//: Uint8Array | number[];
//   let my_fee = -1n;
//   let my_btype = '???';
//   let my_payload_amt = -1n;//', { Map: [Array] } ]
//   let my_payload_to;
//   let my_payload_from;

//   //let aux: Value__1|undefined;
//   // if (my_blocks.blocks[0].block[0] !== undefined) {
      
//   //   const aux: Value__1 = my_blocks.blocks[0].block[0];

//   if (my_blocks.blocks[block_pos].block[0] !== undefined) {
//     const aux: Value__1 = my_blocks.blocks[block_pos].block[0];
//     if ('id' in my_blocks.blocks[block_pos]) {
//       my_block_id = my_blocks.blocks[block_pos].id;
//     }
  
//     if ('Map' in aux) {
//       const aux2 = aux.Map;
//       // console.log("aux")
//       // console.log(aux);
//       // console.log("aux2 = aux.Map")
//       // console.log(aux2);
//       // console.log(aux2[0][1]);
//       if ('Map' in aux2[0][1]) {
//         const aux3 = aux2[0][1];
//         // console.log(aux3.Map);
//         // console.log(aux3.Map[0]);
//         // console.log(aux3.Map[0][0]);
//         // console.log(aux3.Map[0][1]);
//         if ('Nat' in aux3.Map[0][1]) {
//           // console.log(aux3.Map[0][1].Nat);
//           my_block_ts = aux3.Map[0][1].Nat;
//         }
//         if ('Nat' in aux3.Map[1][1]) {
//           // console.log(aux3.Map[1][1].Nat);
//           my_created_at_time = aux3.Map[1][1].Nat;
//         }
//         if ('Blob' in aux3.Map[2][1]) {
//           // console.log(aux3.Map[2][1].Blob);
//           my_memo = aux3.Map[2][1].Blob;
//         }
//         if ('Blob' in aux3.Map[3][1]) {
//           // console.log(aux3.Map[3][1].Blob);
//           my_caller = aux3.Map[3][1].Blob;
//         }
//         if ('Nat' in aux3.Map[4][1]) {
//           // console.log(aux3.Map[4][1].Nat);
//           my_fee = aux3.Map[4][1].Nat;
//         } 
//         if ('Text' in aux3.Map[5][1]) {
//           // console.log(aux3.Map[5][1].Text);
//           my_btype = aux3.Map[5][1].Text;
//         } 
//         if ('Map' in aux3.Map[6][1]) {
//           // console.log(aux3.Map[6][1].Map);
//           const aux4 = aux3.Map[6][1];
//           if ('Nat' in aux4.Map[0][1]) {
//             // console.log(aux4.Map[0][1].Nat);
//             my_payload_amt = aux4.Map[0][1].Nat;
//           }
//           if ('Array' in aux4.Map[1][1]) {
//             // console.log(aux4.Map[1][1].Array);
//             // console.log(aux4.Map[1][0]);
//             if (aux4.Map[1][0] == 'to'){
//               const aux5 = aux4.Map[1][1].Array;
//               // console.log(aux5);
//               if ('Blob' in aux5[0]) {
//                 // console.log(aux5[0].Blob);
//                 my_payload_to = aux5[0].Blob
//               }
//             } else if (aux4.Map[1][0] == 'from'){
//               const aux5 = aux4.Map[1][1].Array;
//               // console.log(aux5);
//               if ('Blob' in aux5[0]) {
//                 // console.log(aux5[0].Blob);
//                 my_payload_from = aux5[0].Blob
//               }
//             }
//           }
//           if (typeof aux4.Map[2] != "undefined") {

//             if ('Array' in aux4.Map[2][1]) {
//               // console.log(aux4.Map[2][1].Array);
//               // console.log(aux4.Map[2][0]);
//               if (aux4.Map[2][0] == 'to'){
//                 const aux5 = aux4.Map[2][1].Array;
//                 // console.log(aux5);
//                 if ('Blob' in aux5[0]) {
//                   // console.log(aux5[0].Blob);
//                   my_payload_to = aux5[0].Blob
//                 }
//               } else if (aux4.Map[2][0] == 'from'){
//                 const aux5 = aux4.Map[2][1].Array;
//                 // console.log(aux5);
//                 if ('Blob' in aux5[0]) {
//                   // console.log(aux5[0].Blob);
//                   my_payload_from = aux5[0].Blob
//                 }
//               }
//             }
//           }
//         } 
//       }
//     } 
//   }

//   return({block_id: my_block_id,
//           block_ts: my_block_ts,
//           created_at_time: my_created_at_time,
//           memo: my_memo,//: Uint8Array | number[];
//           caller: my_caller,//: Uint8Array | number[];
//           fee: my_fee,
//           btype: my_btype,
//           payload_amt: my_payload_amt,//', { Map: [Array] } ]
//           payload_to: my_payload_to,//: Uint8Array | number[];
//           payload_from: my_payload_from});//: Uint8Array | number[];
// };

function decodeBlock2(my_blocks:GetTransactionsResult, block_pos:number ) {
  // console.log(my_blocks.blocks[0]);
  let my_phash;
  let my_auxm1;
  let my_block_id = -1n;
  let my_block_ts = -1n;
  let my_created_at_time = -1n;
  let my_memo;//: Uint8Array | number[];
  let my_caller;//: Uint8Array | number[];
  let my_fee = -1n;
  let my_btype = '???';
  let my_payload_amt = -1n;//', { Map: [Array] } ]
  let my_payload_to;
  let my_payload_from;

  if (my_blocks.blocks[block_pos].block[0] !== undefined) {
    const aux: Value = my_blocks.blocks[block_pos].block[0];
    if ('id' in my_blocks.blocks[block_pos]) {
      my_block_id = my_blocks.blocks[block_pos].id;
    }
    if (block_pos>0) {
      if (my_blocks.blocks[block_pos-1].block[0] !== undefined) {
        my_auxm1 = my_blocks.blocks[block_pos-1].block[0];
      };
    }
    if ('Map' in aux) {
      const aux2 = aux.Map;
      for (let i = 0; i < aux2.length; i++) {
        // phash, ts, btype, tx (created_at_time, memo, caller, fee, payload (amt, from, to))
        switch(aux2[i][0]) {
          case 'phash':
            const aux_phash = aux2[i][1];
            if ('Blob' in aux_phash) {
              my_phash = aux_phash['Blob'];
            };
            break;
          case 'ts':
            const aux_ts = aux2[i][1]
            if ('Nat' in aux_ts) {
              my_block_ts = aux_ts.Nat;
            }
            break;
          case 'btype':
            const aux_btype = aux2[i][1]
            if ('Text' in aux_btype) {
              my_btype = aux_btype.Text;
            } 
            break;
          case 'tx':
            const aux_tx_aux = aux2[i][1];
            if ('Map' in aux_tx_aux) {
              const aux_tx = aux_tx_aux.Map;
              for (let j = 0; j < aux_tx.length; j++) {
                //(created_at_time, memo, caller, fee, payload (amt, from, to)
                switch(aux_tx[j][0]) {
                  case 'created_at_time':
                    const cat_aux = aux_tx[j][1]
                    if ('Nat' in cat_aux) {
                      my_created_at_time = cat_aux.Nat;
                    }
                    break;
                  case 'memo':
                    const memo_aux = aux_tx[j][1]
                    if ('Blob' in memo_aux) {
                      my_memo = memo_aux.Blob;
                    }
                    break;
                  case 'caller':
                    const caller_aux = aux_tx[j][1]
                    if ('Blob' in caller_aux) {
                      my_caller = caller_aux.Blob;
                    }
                    break;
                  case 'fee':
                    const fee_aux = aux_tx[j][1]
                    if ('Nat' in fee_aux) {
                      my_fee = fee_aux.Nat;
                    }
                    break;
                  case 'payload':
                    // amt, from, to
                    const pay_aux = aux_tx[j][1]
                    if ('Map' in pay_aux) {
                      const pay_aux_map = pay_aux.Map;
                      for (let k = 0; k < pay_aux_map.length; k++) {
                        switch(pay_aux_map[k][0]) {
                          case 'amt':
                            const amt_aux = pay_aux_map[k][1];
                            if ('Nat' in amt_aux) {
                              my_payload_amt = amt_aux.Nat;
                            }
                            break;
                          case 'from':
                            const from_aux = pay_aux_map[k][1];
                            if ('Array' in from_aux) {
                              const from_array_aux = from_aux.Array;
                              if ('Blob' in from_array_aux[0]) {
                                my_payload_from = from_array_aux[0].Blob;
                              }
                            }
                            break;
                          case 'to':
                            const to_aux = pay_aux_map[k][1];
                            if ('Array' in to_aux) {
                              const to_array_aux = to_aux.Array;
                              if ('Blob' in to_array_aux[0]) {
                                my_payload_to = to_array_aux[0].Blob;
                              }
                            }
                            break;
                        }
                      }
                    }
                    break
                }
              }
            } 
            break;
          default:
        }
      }
    }
  }
  return({auxm1: my_auxm1,
    phash: my_phash,
    block_id: my_block_id,
    block_ts: my_block_ts,
    created_at_time: my_created_at_time,
    memo: my_memo,//: Uint8Array | number[];
    caller: my_caller,//: Uint8Array | number[];
    fee: my_fee,
    btype: my_btype,
    payload_amt: my_payload_amt,//', { Map: [Array] } ]
    payload_to: my_payload_to,//: Uint8Array | number[];
    payload_from: my_payload_from});//: Uint8Array | number[];
};

describe("Ledger", () => {
  let pic: PocketIc;
  let can: Actor<TestService>;
  let canCanisterId: Principal;

  const jo = createIdentity('superSecretAlicePassword');
  const bob = createIdentity('superSecretBobPassword');
  const ilde = createIdentity('superSecretIldePassword');
  const john1 = createIdentity('superSecretJohn1Password');
  const john2 = createIdentity('superSecretJohn2Password');
  const john3 = createIdentity('superSecretJohn3Password');
  const john4 = createIdentity('superSecretJohn4Password');
  const john5 = createIdentity('superSecretJohn5Password');
  const john6 = createIdentity('superSecretJohn6Password');
  const john7 = createIdentity('superSecretJohn7Password');
  const john8 = createIdentity('superSecretJohn8Password');
  const john9 = createIdentity('superSecretJohn9Password');
  const john0 = createIdentity('superSecretJohn0Password');
  
  beforeAll(async () => {
    pic = await PocketIc.create(process.env.PIC_URL); //ILDE create();


    const fixture = await TestCan(pic, Principal.fromText("aaaaa-aa"));
    can = fixture.actor;
    canCanisterId = fixture.canisterId; //ILDE: I need the id given by
    
    //await can.set_ledger_canister();
  });

  afterAll(async () => {
    await pic.tearDown(); //ILDE: this means "it removes the replica"
  });

  it("check_burnblock_to", async () => {
    let my_mint_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              amt : 50n,
              to : [john0.getPrincipal().toUint8Array()],
          },
      },
    };
    let r_mint = await can.add_record(my_mint_action);
    //let r_mint2 = await can.add_record(my_mint_action);
    //console.log("r_mint:", r_mint);
    
    //expect(r_mint).toBe(0n);
    //let tr: TransactionRange =  {start:10n,length:3n};
    let my_block_args: GetBlocksArgs = [
      {start:0n,length:1n},
      //{start:20n,length:3n},
    ]

    let my_blocks:GetTransactionsResult = await can.icrc3_get_blocks(my_block_args);
    const decodedBlock0 = decodeBlock2(my_blocks,0);   
    const john0_to = john0.getPrincipal().toUint8Array();

    expect(true).toBe(JSON.stringify(john0_to) === JSON.stringify(decodedBlock0.payload_to));
    expect(decodedBlock0.block_id).toBe(0n);
    console.log(my_blocks.log_length, my_blocks.blocks);
    expect(my_blocks.log_length).toBe(1n);
  });

  it("check_last_online_ledger_position", async () => {
    // destroy canister to make sure ledger size is 0
    await pic.tearDown(); 
    // create canister again 
    pic = await PocketIc.create(process.env.PIC_URL); //ILDE create();
    const fixture = await TestCan(pic, Principal.fromText("aaaaa-aa"));
    can = fixture.actor;
    canCanisterId = fixture.canisterId; 

    let my_mint_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              to : [bob.getPrincipal().toUint8Array()],
              amt : 100n,
          },
      },
    };

    let i = 0n;
    const num_blocks = 10n;
    for (; i < num_blocks; i++) {
      let r = await can.add_record(my_mint_action);
    }

    let my_block_args: GetBlocksArgs = [
       {start:0n,length: num_blocks},
    ]

    let my_blocks:GetTransactionsResult = await can.icrc3_get_blocks(my_block_args);
 
    expect(BigInt(my_blocks.blocks.length)).toBe(num_blocks);

    const num_blocks2 = 11n;
    my_block_args = [
      {start:0n,length: num_blocks2},
    ]

    my_blocks = await can.icrc3_get_blocks(my_block_args);

    expect(BigInt(my_blocks.blocks.length)).toBe(num_blocks);

    const num_blocks3 = 9n;
    my_block_args = [
      {start:0n,length: num_blocks3},
    ]

    my_blocks = await can.icrc3_get_blocks(my_block_args);

    expect(BigInt(my_blocks.blocks.length)).toBe(num_blocks3);
    expect(BigInt(my_blocks.log_length)).toBe(num_blocks);


    // for (let i=0; i < num_blocks3; i++) {
    //   console.log(i,my_blocks.blocks[i].id);      
    // }

  });

  it("add_mint_record1", async () => {
    let my_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          // #burn : {
          //     amt: Nat;
          //     from: [Blob];
          // };
          // #transfer : {
          //     to : [Blob];
          //     from : [Blob];
          //     amt : Nat;
          // };
          // #transfer_from : {
          //     to : [Blob];
          //     from : [Blob];
          //     amt : Nat;
          // };
          mint : {
              to : [ilde.getPrincipal().toUint8Array()],
              amt : 100n,
          },
      },
    };
    let r = await can.add_record(my_action);
    expect(true).toBe('Ok' in r);
  });

  it("add_mint_burn_check1", async () => {
    let my_mint_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              to : [john4.getPrincipal().toUint8Array()],
              amt : 100n,
          },
      },
    };
    let my_burn_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          burn : {
              amt : 50n,
              from : [john4.getPrincipal().toUint8Array()],
          },
      },
    };
    let r_mint = await can.add_record(my_mint_action);
    let r_burn = await can.add_record(my_burn_action);

    //{ owner : Principal; subaccount : ?Blob };
    let my_account: Account = {
      owner : john4.getPrincipal(),
      subaccount: [], 
    };
    let r_bal = await can.icrc1_balance_of(my_account);  

    expect(r_bal).toBe(50n);
  });

  it("trigger_archive1", async () => {
    let my_action: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              to : [john1.getPrincipal().toUint8Array()],
              amt : 100n,
          },
      },
    };

    let i = 0n;
    for (; i < 5; i++) {
      let r = await can.add_record(my_action);
      console.log(i);
    }
    
    expect(i).toBe(5n);
  });

  it("retrieve_blocks_online1", async () => {
    //let tr: TransactionRange =  {start:10n,length:3n};
    let my_block_args: GetBlocksArgs = [
      {start:0n,length:3n},
      //{start:20n,length:3n},
    ]
    //   public type TransactionRange = {
    //     start : Nat;
    //     length : Nat;
    // };
    //   public type GetTransactionsResult = {
    //     // Total number of transactions in the
    //     // transaction log
    //     log_length : Nat;        
    //     blocks : [{ id : Nat; block : ?Value }];
    //     archived_blocks : [ArchivedTransactionResponse];
    // };
    let my_blocks:GetTransactionsResult = await can.icrc3_get_blocks(my_block_args);
    expect(my_blocks.blocks.length).toBe(3);
  });

  it("check_online_block_content1", async () => {
    //let tr: TransactionRange =  {start:10n,length:3n};
    let my_block_args: GetBlocksArgs = [
      {start:0n,length:2n},
      //{start:20n,length:3n},
    ]

    let my_blocks:GetTransactionsResult = await can.icrc3_get_blocks(my_block_args);
    
    const decodedBlock0 = decodeBlock2(my_blocks,0);
    const decodedBlock1 = decodeBlock2(my_blocks,1);
    expect(decodedBlock0.block_id).toBe(0n);
    expect(decodedBlock1.block_id).toBe(1n);
    expect(my_blocks.blocks.length).toBe(2);
  });

  it("check_balance_afater_mints_burns_transfers1", async () => {
    let my_mint_action1: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              to : [john8.getPrincipal().toUint8Array()],
              amt : 100n,
          },
      },
    };
    let my_burn_action1: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          burn : {
              amt : 50n,
              from : [john8.getPrincipal().toUint8Array()],
          },
      },
    };
    let my_mint_action2: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          mint : {
              to : [john9.getPrincipal().toUint8Array()],
              amt : 1000n,
          },
      },
    };
    let my_burn_action2: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          burn : {
              amt : 500n,
              from : [john9.getPrincipal().toUint8Array()],
          },
      },
    };
    let my_transfer_action1: Action = {
      ts : 0n,
      created_at_time : [0n], //?Nat64
      memo: [], //?Blob;
      caller: jo.getPrincipal(),  
      fee: [], //?Nat
      payload : {
          transfer : {
              amt : 100n,
              from : [john9.getPrincipal().toUint8Array()],
              to: [john8.getPrincipal().toUint8Array()],
          },
      },
    };

    let r_mint1 = await can.add_record(my_mint_action1);
    let r_burn1 = await can.add_record(my_burn_action1);
    let r_mint2 = await can.add_record(my_mint_action2);
    let r_burn2 = await can.add_record(my_burn_action2);

    let my_account1: Account = {
      owner : john8.getPrincipal(),
      subaccount: [], 
    };
    let r_bal1 = await can.icrc1_balance_of(my_account1);  
    expect(r_bal1).toBe(50n);

    let my_account2: Account = {
      owner : john9.getPrincipal(),
      subaccount: [], 
    };
    let r_bal2 = await can.icrc1_balance_of(my_account2);  
    expect(r_bal2).toBe(500n);

    let r_transfer1 = await can.add_record(my_transfer_action1);
    let r_bal3 = await can.icrc1_balance_of(my_account2); 
    console.log("balance of john9:",r_bal3); 
    expect(r_bal3).toBe(400n);
  });

  // O check bugs in get_blocks (-1)
  // O do decoding function to clean testing code 
  // O test very last block position in online ledger
  // O test content of blocks
  // O test account balnce after combinations of mint, burn and transfers
  // O test ids
  //    L> Need to return block id after creating it
  // Dedup reducer test
  // test archived retrival of archived blocks
  // create many archives

  async function passTime(n: number) {
    for (let i = 0; i < n; i++) {
      await pic.advanceTime(3 * 1000);
      await pic.tick(2);
    }
  }
});
