import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
import { _SERVICE as TestService, idlFactory as TestIdlFactory, init } from './build/basic.idl.js';

// ILDE import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
//@ts-ignore
import {toState} from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

const WASM_PATH = resolve(__dirname, "./build/basic.wasm");

export async function TestCan(pic:PocketIc, ledgerCanisterId:Principal) {
    
    const fixture = await pic.setupCanister<TestService>({
        idlFactory: TestIdlFactory,
        wasm: WASM_PATH,
        arg: IDL.encode(init({ IDL }), [{ledgerId: ledgerCanisterId}]),
    });

    return fixture;
};


describe('Basic', () => {
    let pic: PocketIc;
    let can: Actor<TestService>;
    let canCanisterId: Principal;

    // const jo = createIdentity('superSecretAlicePassword');
    // const bob = createIdentity('superSecretBobPassword');
  
    beforeAll(async () => {

      pic = await PocketIc.create(process.env.PIC_URL);//ILDE create();
  
      const fixture = await TestCan(pic, Principal.fromText("aaaaa-aa"));
      can = fixture.actor;
      canCanisterId = fixture.canisterId; //ILDE: I need the id given by 

    });
  
    afterAll(async () => {
      await pic.tearDown();  //ILDE: this means "it removes the replica"
    });
  
    

    it('tests', async () => {
      let r = await can.test();
      expect(r).toBe(5n);
    });

    // it('tests2',  () => {
    //   let r = can.set_ledger_canister();
    //   expect(r).toBe(5n);
    // });


    async function passTime(n:number) {
    for (let i=0; i<n; i++) {
        await pic.advanceTime(3*1000);
        await pic.tick(2);
      }
    }

});