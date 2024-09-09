import { Principal } from "@dfinity/principal";
import { resolve } from "node:path";
import { Actor, PocketIc, createIdentity} from "@hadronous/pic";

import { IDL } from "@dfinity/candid";


import {
  _SERVICE as TestService_noarchive,
  idlFactory as TestIdlFactory_noarchive,
  init as init_noarchive,
} from "./build/reader_noarchive.idl.js";

import {
  // Action,
  // Account,
  // GetBlocksArgs,
  // TransactionRange,
  // GetTransactionsResult,
  // Value__1,
} from "./build/reader_noarchive.idl.js";

import {
  _SERVICE as TestService_ledger,
  idlFactory as TestIdlFactory_ledger,
  init as init_ledger,
} from "./build/reader_ledger.idl.js";

import {
  Action,
  Account,
  GetBlocksArgs,
  TransactionRange,
  GetTransactionsResult,
  Value__1,
} from "./build/reader_ledger.idl.js";

import {
  _SERVICE as TestService_reader,
  idlFactory as TestIdlFactory_reader,
  init as init_reader,
} from "./build/reader_reader.idl.js";

import {
  // Action,
  // Account,
  // GetBlocksArgs,
  // TransactionRange,
  // GetTransactionsResult,
  // Value__1,
} from "./build/reader_reader.idl.js";
//@ts-ignore
import { toState } from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

const READER_READER_WASM_PATH = resolve(__dirname, "./build/reader_reader.wasm");
const READER_LEDGER_WASM_PATH = resolve(__dirname, "./build/reader_ledger.wasm");
const READER_NOARCHIVE_WASM_PATH = resolve(__dirname, "./build/reader_noarchive.wasm");


export async function TestLedger(pic: PocketIc, ledgerCanisterId: Principal) {
  const fixture = await pic.setupCanister<TestService_ledger>({
    idlFactory: TestIdlFactory_ledger,
    wasm: READER_LEDGER_WASM_PATH,
    arg: IDL.encode(init_ledger({ IDL }),[]), 
  });

  return fixture;
}

export async function TestNoarchive(pic: PocketIc, noarchiveCanisterId: Principal) {
  const fixture = await pic.setupCanister<TestService_noarchive>({
    idlFactory: TestIdlFactory_noarchive,
    wasm: READER_NOARCHIVE_WASM_PATH,
    arg: IDL.encode(init_ledger({ IDL }),[]), 
  });

  return fixture;
}

export async function TestReader(pic: PocketIc, readerCanisterId: Principal, ledger_pid: Principal, noarchive_pid: Principal) {
  const fixture = await pic.setupCanister<TestService_reader>({
    idlFactory: TestIdlFactory_reader,
    wasm: READER_READER_WASM_PATH,
    arg: IDL.encode(init_reader({ IDL }), [ledger_pid, noarchive_pid]), 
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

describe("reader", () => {
  let pic: PocketIc;
  let can_ledger: Actor<TestService_ledger>;
  let canCanisterId_ledger: Principal;
  let can_noarchive: Actor<TestService_noarchive>;
  let canCanisterId_noarchive: Principal;
  let can_reader: Actor<TestService_reader>;
  let canCanisterId_readerr: Principal;

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
    pic = await PocketIc.create(process.env.PIC_URL); 

    //Create ledger
    const fixture_ledger = await TestLedger(pic, Principal.fromText("aaaaa-aa"));
    can_ledger = fixture_ledger.actor;
    canCanisterId_ledger = fixture_ledger.canisterId; 
    
    await can_ledger.set_ledger_canister();

    //Create noarchive
    const fixture_noarchive = await TestNoarchive(pic, Principal.fromText("aaaaa-aa"));
    can_noarchive = fixture_noarchive.actor;
    canCanisterId_noarchive = fixture_noarchive.canisterId; 

    //Create reader
    const fixture_reader = await TestReader(pic, Principal.fromText("aaaaa-aa"), canCanisterId_ledger, canCanisterId_noarchive);
    can_reader = fixture_reader.actor;
    canCanisterId_ledger = fixture_reader.canisterId; 

  });

  afterAll(async () => {
    await pic.tearDown(); //this means "it removes the replica"
  });

  it("check_balance_in_reader_after_mints", async () => {
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
    
    let i = 0n;
    for (; i < 500; i++) {
      let r = await can_ledger.add_record(my_mint_action);
    }
    
    await passTime(100);

    await can_reader.start_timer();

    await passTime(5);

    let my_account : Account = {'owner' : john0.getPrincipal(),
                                'subaccount' : []};
    let r_balance = await can_ledger.icrc1_balance_of(my_account);
    
    console.log("John0 balance: ", r_balance);

    // const num_blocks = 25000n;
    // let my_block_args = [
    //   {start:0n,length: num_blocks},
    // ];

    // let my_blocks = await can_ledger.icrc3_get_blocks(my_block_args);

    // console.log("number of blocks:",my_blocks);
    
    //start reader
    //do some waiting
    await passTime(200);

    let r_balance2 = await can_noarchive.icrc1_balance_of(my_account);
    console.log("John0 balance on noarchive: ", r_balance2);

    // expect(r_balance).toBe(r_balance2);

  },600000);

  // it("check_balance_in_reader_after_burns", async () => {
  //   let my_burn_action: Action = {
  //     ts : 0n,
  //     created_at_time : [0n], //?Nat64
  //     memo: [], //?Blob;
  //     caller: jo.getPrincipal(),  
  //     fee: [], //?Nat
  //     payload : {
  //         burn : {
  //             amt : 50n,
  //             from : [john0.getPrincipal().toUint8Array()],
  //         },
  //     },
  //   };
    
  //   let i = 0n;
  //   for (; i < 250; i++) {
  //     let r = await can_ledger.add_record(my_burn_action);
  //   }

  //   await passTime(10);
    
  //   let account1 : Account = {'owner' : john0.getPrincipal(),
  //                             'subaccount' : []};
    
  //   let r_balance = await can_ledger.icrc1_balance_of(account1);
  //   console.log("John1 balance: ", r_balance);
    
  //   expect(r_balance).toBe(12500n);

  //   let r_balance2 = await can_noarchive.icrc1_balance_of(account1);
  //   console.log("John0 balance on noarchive: ", r_balance2);

  //   expect(r_balance).toBe(r_balance2);

  // },60000);

  // it("check_balance_in_reader_after_transfers", async () => {
  //   let my_transfer_action: Action = {
  //     ts : 0n,
  //     created_at_time : [0n], //?Nat64
  //     memo: [], //?Blob;
  //     caller: jo.getPrincipal(),  
  //     fee: [], //?Nat
  //     payload : {
  //         transfer : {
  //             amt : 50n,
  //             from : [john0.getPrincipal().toUint8Array()],
  //             to : [john1.getPrincipal().toUint8Array()],
  //         },
  //     },
  //   };

  //   let i = 0n;
  //   for (; i < 200; i++) {
  //     let r = await can_ledger.add_record(my_transfer_action);
  //   }
    
  //   await passTime(10);

  //   let account1 : Account = {'owner' : john1.getPrincipal(),
  //     'subaccount' : []};

  //   let r_balance = await can_ledger.icrc1_balance_of(account1);
  //   console.log("John1 balance: ", r_balance);
    
  //   let r_balance2 = await can_noarchive.icrc1_balance_of(account1);
  //   console.log("John1 balance on noarchive: ", r_balance2);
    
  //   expect(r_balance2).toBe(10000n);


  // },60000); 

  // it("transfer", async () => {
  //   //<--------
  // },60000);

  async function passTime(n: number) {
    for (let i = 0; i < n; i++) {
      await pic.advanceTime(3 * 1000);
      await pic.tick(2);
    }
  }
  
});

