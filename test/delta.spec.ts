import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
import { _SERVICE as TestService, idlFactory as TestIdlFactory, init, ArchivedTransactionResponse, GetBlocksResult } from './build/delta.idl.js';
import { _SERVICE as MgrService, idlFactory as MgrIdlFactory } from './services/mgr.js';

//@ts-ignore
import { toState } from "@infu/icblast";

const WASM_PATH = resolve(__dirname, "./build/delta.wasm");

export async function TestCan(pic: PocketIc, archive_controllers: Principal[] = []) {

  const fixture = await pic.setupCanister<TestService>({
    idlFactory: TestIdlFactory,
    wasm: WASM_PATH,
    arg: IDL.encode(init({ IDL }), [{ archive_controllers }]),
  });

  await pic.addCycles(fixture.canisterId, 200_000_000_000_000);

  return fixture;
};

describe('Delta', () => {
  let pic: PocketIc;
  let can: Actor<TestService>;
  let canCanisterId: Principal;
  let mgr: Actor<MgrService>;
  const jo = createIdentity('superSecretAlicePassword');
  const bob = createIdentity('superSecretBobPassword');

  beforeAll(async () => {
    pic = await PocketIc.create(process.env.PIC_URL);
    const fixture = await TestCan(pic, [jo.getPrincipal(), bob.getPrincipal(), Principal.fromText("2vxsx-fae")]);
    can = fixture.actor;
    canCanisterId = fixture.canisterId;

    await can.set_ledger_canister();

    mgr = pic.createActor<MgrService>(MgrIdlFactory, Principal.fromText("aaaaa-aa"));

  });

  afterAll(async () => {
    await pic.tearDown(); 
  });

  it('empty dispatch', async () => {
    let r = await can.dispatch([]);
    expect(r.length).toBe(0);
  });

  it('empty log', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 100n
    }]);
    expect(rez.archived_blocks.length).toBe(0);
    expect(rez.blocks.length).toBe(0);
    expect(rez.log_length).toBe(0n);
  });

  it("dispatch 1 action", async () => {

    let r = await can.dispatch([{
      ts: 12340n,
      created_at_time: 1721045569580000n,
      memo: [0, 1, 2, 3, 4],
      caller: Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"),
      fee: 1000n,
      payload: {
        swap: { amt: 123456n }
      }
    }]);
    expect(toState(r[0]).Ok).toBe("1");
  });

  it("dispatch 300 actions in 300 calls", async () => {
    for (let i = 0; i < 300; i++) {
      let r = await can.dispatch([{
        ts: 12340n,
        created_at_time: 1721045569580000n,
        memo: [0, 1, 2, 3, 4],
        caller: Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"),
        fee: 1000n,
        payload: {
          swap: { amt: 123456n }
        }
      }]);
      expect(toState(r[0]).Ok).toBe((2 + i).toString());
    }
    await passTime(20);
  });


  it('icrc3_get_blocks 100', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 100n
    }]);
    let archive_rez = await getArchived(rez.archived_blocks[0]);

    expect(archive_rez.blocks[5].id).toBe(5n);

  });


  it("dispatch 300 actions in 1 call", async () => {
    let r = await can.dispatch(Array.from({ length: 300 }, () => ({
      ts: 12340n,
      created_at_time: 1721045569580000n,
      memo: [0, 1, 2, 3, 4],
      caller: Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"),
      fee: 1000n,
      payload: {
        swap: { amt: 123456n }
      }
    })));
    expect(toState(r[0]).Ok).toBe("302");
    await passTime(20);
  });

  let data_before_upgrade: GetBlocksResult;
  let data_before_upgrade_archive_0: GetBlocksResult;
  let data_before_upgrade_archive_1: GetBlocksResult;
  let data_before_upgrade_archive_2: GetBlocksResult;
  let data_before_upgrade_archive_3: GetBlocksResult;
  let data_before_upgrade_archive_4: GetBlocksResult;

  it('icrc3_get_blocks 601', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 800n
    }]);

    console.log(rez.blocks[0].id);

    expect(rez.blocks[0].id).toBe(360n);

  });

  async function passTime(n: number) {
    for (let i = 0; i < n; i++) {
      await pic.advanceTime(3 * 1000);
      await pic.tick(2);
    }
  }

  async function getArchived(arch_param: ArchivedTransactionResponse): Promise<GetBlocksResult> {
    let archive_principal = Principal.fromText(toState(arch_param).callback[0]);
    const archive_actor = pic.createActor<TestService>(TestIdlFactory, archive_principal);
    let args = arch_param.args[0]
    return await archive_actor.icrc3_get_blocks([args]);
  }
});