import { Principal } from "@dfinity/principal";
import { resolve } from "node:path";
import { Actor, PocketIc, createIdentity} from "@hadronous/pic";

import { IDL } from "@dfinity/candid";
import {
  _SERVICE as TestService,
  idlFactory as TestIdlFactory,
  init,
} from "./build/cert.idl.js";

import {
  Action,
  DataCertificate,
  Account,
  GetBlocksArgs,
  TransactionRange,
  GetTransactionsResult,
} from "./build/cert.idl.js";
import { HttpAgent, compare, lookup_path } from '@dfinity/agent';
import { verifyCertification } from '@dfinity/certificate-verification';

//@ts-ignore
import { toState } from "@infu/icblast";

const WASM_PATH = resolve(__dirname, "./build/cert.wasm");
export async function TestCan(pic:PocketIc) {
  
  const nnsSubnet = pic.getNnsSubnet();
  if (!nnsSubnet) {
      throw new Error('NNS subnet not found');
  }  

  const fixture = await pic.setupCanister<TestService>({
      idlFactory: TestIdlFactory,
      wasm: WASM_PATH,
      arg: IDL.encode(init({ IDL }), []),
      targetSubnetId:nnsSubnet.id,});

  return fixture;
};

describe("Cert", () => {
  let pic: PocketIc;
  let can: Actor<TestService>;
  let canCanisterId: Principal;

  const jo = createIdentity('superSecretAlicePassword');
  
  beforeAll(async () => {

    pic = await PocketIc.create(process.env.PIC_URL, {nns:true}); 

    const fixture = await TestCan(pic);
    can = fixture.actor;
    canCanisterId = fixture.canisterId; 

    await pic.resetTime();
    const time = await pic.getTime();
    console.log("date", new Date(time));

  });

  afterAll(async () => {
    await pic.tearDown(); 
  });

  it("test_mintblock_cert1", async () => {
    let my_mint_action: Action = {
      ts : 0n,
      created_at_time : [0n],
      memo: [], 
      caller: jo.getPrincipal(),  
      fee: [], 
      payload : {
          mint : {
              amt : 50n,
              to : [jo.getPrincipal().toUint8Array()],
          },
      },
    };
    let r_mint = await can.add_record(my_mint_action);
    expect(true).toBe('Ok' in r_mint);

    const nnsSubnet = pic.getNnsSubnet();
    if (!nnsSubnet) {
      throw new Error('NNS subnet not found');
    }

    const rootKey = await pic.getPubKey(nnsSubnet.id);

    

    let data_cert: []|[DataCertificate] = await can.icrc3_get_tip_certificate(); 
    if (data_cert != null) {
      let ddddd: undefined|DataCertificate = data_cert[0];
      if (typeof ddddd != "undefined") {
        const certificate = ddddd.certificate;
        const witness = ddddd.hash_tree;

        let inputs = {
              canisterId: canCanisterId,
              encodedCertificate: new Uint8Array(certificate),
              encodedTree: new Uint8Array(witness),
              rootKey: new Uint8Array(rootKey),
              maxCertificateTimeOffsetMs: 500000000,
            };
            console.log("inputs:", inputs)
        
        function i2hex(i:number ) {
          return ('0' + i.toString(16)).slice(-2);
        };

        const cert_hex = Array.from(new Uint8Array(certificate)).map(i2hex).join('');
        const wit_hex = Array.from(new Uint8Array(witness)).map(i2hex).join('');

        console.log("certificate:", cert_hex);
        console.log("witness:",wit_hex);

        const tree = await verifyCertification({
          canisterId: canCanisterId,
          encodedCertificate: new Uint8Array(certificate),
          encodedTree: new Uint8Array(witness),
          rootKey:  new Uint8Array(rootKey),
          maxCertificateTimeOffsetMs: 50000,
        });

        console.log("cert: ", ddddd.certificate);
      };
    };
  });

  async function passTime(n: number) {
    for (let i = 0; i < n; i++) {
      await pic.advanceTime(3 * 1000);
      await pic.tick(2);
    }
  }
});
