import { Principal } from "@dfinity/principal";
import { resolve } from "node:path";
import { Actor, PocketIc, createIdentity} from "@hadronous/pic";

import { IDL } from "@dfinity/candid";
import {
  _SERVICE as TestService,
  idlFactory as TestIdlFactory,
  init,
} from "./build/phash.idl.js";

import {
  Action,
  Account,
  GetBlocksArgs,
  TransactionRange,
  GetTransactionsResult,
  Value__1,
} from "./build/phash.idl.js";

//@ts-ignore
import { toState } from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

const WASM_PATH = resolve(__dirname, "./build/phash.wasm");

export async function TestCan(pic: PocketIc, ledgerCanisterId: Principal) {
  const fixture = await pic.setupCanister<TestService>({
    idlFactory: TestIdlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(init({ IDL }), []), 
  });

  return fixture;
}


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
    const aux: Value__1 = my_blocks.blocks[block_pos].block[0];
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

// function decodeBlock(my_blocks:GetTransactionsResult, block_pos:number ) {
//   // console.log(my_blocks.blocks[0]);
//   let my_phash;
//   let my_auxm1;
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

//   console.log("my_blocks:",my_blocks);
//   if (my_blocks.blocks[block_pos].block[0] !== undefined) {
//     //console.log("my_blocks.blocks[block_pos].block[0]:",my_blocks.blocks[block_pos].block[0]);
//     console.log("my_blocks.blocks[block_pos].block[0]:",my_blocks.blocks[block_pos].block[0]);
//     const aux: Value__1 = my_blocks.blocks[block_pos].block[0];
//     if ('id' in my_blocks.blocks[block_pos]) {
//       my_block_id = my_blocks.blocks[block_pos].id;
//       console.log("my_block_id:",my_block_id);
//     }
//     if (block_pos>0) {
//       if (my_blocks.blocks[block_pos-1].block[0] !== undefined) {
//         my_auxm1 = my_blocks.blocks[block_pos-1].block[0];
//         console.log ("my_auxm1:",my_auxm1);
//       };
//     }
//     if ('Map' in aux) {
//       console.log("aux:", aux);
//       const aux2 = aux.Map;


//       let auxaux = aux2[0][1];
//       if (aux2.length>1) {
//         auxaux = aux2[1][1];
//         if ('Blob' in aux2[0][1]) {
//           my_phash = aux2[0][1]['Blob'];
//         };
//       };
//       if ('Map' in auxaux) {//aux2[0][1]) {
//         const aux3 = auxaux;
//         if ('Nat' in aux3.Map[0][1]) {
//           my_block_ts = aux3.Map[0][1].Nat;
//         }
//         if ('Nat' in aux3.Map[1][1]) {
//           my_created_at_time = aux3.Map[1][1].Nat;
//         }
//         if ('Blob' in aux3.Map[2][1]) {
//           my_memo = aux3.Map[2][1].Blob;
//         }
//         if ('Blob' in aux3.Map[3][1]) {
//           my_caller = aux3.Map[3][1].Blob;
//         }
//         if ('Nat' in aux3.Map[4][1]) {
//           my_fee = aux3.Map[4][1].Nat;
//         } 
//         if ('Text' in aux3.Map[5][1]) {
//           my_btype = aux3.Map[5][1].Text;
//         } 
//         if ('Map' in aux3.Map[6][1]) {
//           const aux4 = aux3.Map[6][1];
//           if ('Nat' in aux4.Map[0][1]) {
//             my_payload_amt = aux4.Map[0][1].Nat;
//           }
//           if ('Array' in aux4.Map[1][1]) {
//             if (aux4.Map[1][0] == 'to'){
//               const aux5 = aux4.Map[1][1].Array;
//               if ('Blob' in aux5[0]) {
//                 my_payload_to = aux5[0].Blob
//               }
//             } else if (aux4.Map[1][0] == 'from'){
//               const aux5 = aux4.Map[1][1].Array;
//               if ('Blob' in aux5[0]) {
//                 my_payload_from = aux5[0].Blob
//               }
//             }
//           }
//           if (typeof aux4.Map[2] != "undefined") {

//             if ('Array' in aux4.Map[2][1]) {
//               if (aux4.Map[2][0] == 'to'){
//                 const aux5 = aux4.Map[2][1].Array;
//                 if ('Blob' in aux5[0]) {
//                   my_payload_to = aux5[0].Blob
//                 }
//               } else if (aux4.Map[2][0] == 'from'){
//                 const aux5 = aux4.Map[2][1].Array;
//                 if ('Blob' in aux5[0]) {
//                   my_payload_from = aux5[0].Blob
//                 }
//               }
//             }
//           }
//         } 
//       }
//     } 
//   }

//   return({auxm1: my_auxm1,
//           phash: my_phash,
//           block_id: my_block_id,
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



describe("phash", () => {
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
    canCanisterId = fixture.canisterId; 
    
    await can.set_ledger_canister();

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
    let r_mint2 = await can.add_record(my_mint_action);
    let r_mint3 = await can.add_record(my_mint_action);
    
    let my_block_args: GetBlocksArgs = [
      {start:0n,length:3n}, 
    ]

    let my_blocks:GetTransactionsResult = await can.icrc3_get_blocks(my_block_args);

    const decodedBlock0 = decodeBlock2(my_blocks,1); 
    const decodedBlock1 = decodeBlock2(my_blocks,1); 
    const decodedBlock2 = decodeBlock2(my_blocks,2); 
    //console.log("decodedBlock0", decodedBlock0);
    //console.log("decodedBlock1", decodedBlock1);
    //console.log("decodedBlock2", decodedBlock2);
    const john0_to = john0.getPrincipal().toUint8Array();

    expect(true).toBe(JSON.stringify(john0_to) === JSON.stringify(decodedBlock1.payload_to));

    if (typeof decodedBlock1.auxm1 !== 'undefined') {
      const auxm1 = decodedBlock1.auxm1;
      const phash_hat1 = await can.compute_hash(auxm1);
      expect(true).toBe(JSON.stringify(decodedBlock1.phash) === JSON.stringify(phash_hat1[0]));
    };

    if (typeof decodedBlock2.auxm1 !== 'undefined') {
      const auxm2 = decodedBlock2.auxm1;
      const phash_hat2 = await can.compute_hash(auxm2);
      expect(true).toBe(JSON.stringify(decodedBlock2.phash) === JSON.stringify(phash_hat2[0]));
    };
   
  });

  // it("check_archives_balance", async () => {
       
    
  //   let my_mint_action: Action = {
  //     ts : 0n,
  //     created_at_time : [0n], //?Nat64
  //     memo: [], //?Blob;
  //     caller: jo.getPrincipal(),  
  //     fee: [], //?Nat
  //     payload : {
  //         mint : {
  //             amt : 50n,
  //             to : [john0.getPrincipal().toUint8Array()],
  //         },
  //     },
  //   };

  //   let i = 0n;
  //   for (; i < 35; i++) {
  //     let r = await can.add_record(my_mint_action);
  //     //console.log(i);
  //   }
  //   console.log(i);

  //   await passTime(200);

  //   i = 0n;
  //   for (; i < 35; i++) {
  //     let r = await can.add_record(my_mint_action);
  //     //console.log(i);
  //   }
  //   console.log(i);

  //   await passTime(200);
    
  //   await can.check_archives_balance();
    
  //   await passTime(200);

  //   i = 0n;
  //   for (; i < 35; i++) {
  //     let r = await can.add_record(my_mint_action);
  //     //console.log(i);
  //   }
  //   console.log(i);
    
  //   await passTime(200);
    
  //   const ret = await can.check_archives_balance();
    
  //   console.log(ret);

  //   await passTime(200);

  //   expect(true).toBe(true);
   
  // });

  async function passTime(n: number) {
    for (let i = 0; i < n; i++) {
      await pic.advanceTime(3 * 1000);
      await pic.tick(2);
    }
  }
  
});

