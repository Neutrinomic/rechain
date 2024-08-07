import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
import { _SERVICE as TestService, idlFactory as TestIdlFactory, init, ArchivedTransactionResponse, GetBlocksResult } from './build/delta.idl.js';
import { _SERVICE as MgrService, idlFactory as MgrIdlFactory } from './services/mgr.js';

// ILDE import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
//@ts-ignore
import { toState } from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

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
    await pic.tearDown();  //ILDE: this means "it removes the replica"
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

  it('icrc3_get_blocks with 1 block', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 100n
    }]);
    let strblock = JSON.stringify(toState(rez.blocks[0]));
    expect(strblock).toBe('{"id":"0","block":[{"Map":[["tx",{"Map":[["ts",{"Nat":"12340"}],["created_at_time",{"Nat":"1721045569580000"}],["memo",{"Blob":"0001020304"}],["caller",{"Blob":"00000000020000870101"}],["fee",{"Nat":"1000"}],["btype",{"Text":"1swap"}],["payload",{"Map":[["amt",{"Nat":"123456"}]]}]]}]]}]}');
    expect(rez.log_length).toBe(1n);
    expect(rez.archived_blocks.length).toBe(0);
    expect(rez.blocks.length).toBe(1);

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


  it('icrc3_get_blocks first 301', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 500n
    }]);


    expect(rez.blocks[0].id).toBe(240n);
    expect(rez.blocks[rez.blocks.length - 1].id).toBe(300n);

    let archive_rez_0 = await getArchived(rez.archived_blocks[0]);
    expect(archive_rez_0.blocks[0].id).toBe(0n);
    expect(archive_rez_0.blocks[archive_rez_0.blocks.length - 1].id).toBe(119n);

    let archive_rez_1 = await getArchived(rez.archived_blocks[1]);
    expect(archive_rez_1.blocks[0].id).toBe(120n);
    expect(archive_rez_1.blocks[archive_rez_1.blocks.length - 1].id).toBe(239n);

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

    expect(rez.blocks[0].id).toBe(571n);
    expect(rez.blocks[rez.blocks.length - 1].id).toBe(600n);

    let archive_rez_0 = await getArchived(rez.archived_blocks[0]);
    expect(archive_rez_0.blocks[0].id).toBe(0n);
    expect(archive_rez_0.blocks[archive_rez_0.blocks.length - 1].id).toBe(119n);

    let archive_rez_1 = await getArchived(rez.archived_blocks[1]);
    expect(archive_rez_1.blocks[0].id).toBe(120n);
    expect(archive_rez_1.blocks[archive_rez_1.blocks.length - 1].id).toBe(239n);

    let archive_rez_2 = await getArchived(rez.archived_blocks[2]);
    expect(archive_rez_2.blocks[0].id).toBe(240n);
    expect(archive_rez_2.blocks[archive_rez_2.blocks.length - 1].id).toBe(359n);

    let archive_rez_3 = await getArchived(rez.archived_blocks[3]);
    expect(archive_rez_3.blocks[0].id).toBe(360n);
    expect(archive_rez_3.blocks[archive_rez_3.blocks.length - 1].id).toBe(479n);

    let archive_rez_4 = await getArchived(rez.archived_blocks[4]);
    expect(archive_rez_4.blocks[0].id).toBe(480n);
    expect(archive_rez_4.blocks[archive_rez_4.blocks.length - 1].id).toBe(570n);

    data_before_upgrade = rez;
    data_before_upgrade_archive_0 = archive_rez_0;
    data_before_upgrade_archive_1 = archive_rez_1;
    data_before_upgrade_archive_2 = archive_rez_2;
    data_before_upgrade_archive_3 = archive_rez_3;
    data_before_upgrade_archive_4 = archive_rez_4;



  });


  it('upgrade canister', async () => {
    let can_last_updated = await can.last_modified();
    await passTime(10);
    await pic.upgradeCanister({ canisterId: canCanisterId, wasm: WASM_PATH, arg: IDL.encode(init({ IDL }), [{ archive_controllers: [jo.getPrincipal(), bob.getPrincipal(), Principal.fromText("2vxsx-fae")] }]) });
    let can_last_updated_after = await can.last_modified();
    expect(Number(can_last_updated)).toBeLessThan(Number(can_last_updated_after));

  });

  it('upgrade canister + archives', async () => {
    let archives = await can.icrc3_get_archives({ from: [] });
    let archive_times = [];
    for (let i = 0; i < archives.length; i++) {
      let archive_actor = pic.createActor<TestService>(TestIdlFactory, archives[i].canister_id);
      archive_times.push(await archive_actor.last_modified());
    }

    await passTime(10);
    let can_last_updated = await can.last_modified();
    await pic.upgradeCanister({ canisterId: canCanisterId, wasm: WASM_PATH, arg: IDL.encode(init({ IDL }), [{ archive_controllers: [jo.getPrincipal(), bob.getPrincipal(), Principal.fromText("2vxsx-fae")] }]) });
    let can_last_updated_after = await can.last_modified();
    expect(Number(can_last_updated)).toBeLessThan(Number(can_last_updated_after));


    let archive_times_new = [];
    for (let i = 0; i < archives.length; i++) {
      let archive_actor = pic.createActor<TestService>(TestIdlFactory, archives[i].canister_id);
      archive_times_new.push(await archive_actor.last_modified());
    }

    for (let i = 0; i < archives.length; i++) {
      expect(Number(archive_times[i])).toBeLessThan(Number(archive_times_new[i]));
    }

  });



  it('icrc3_get_blocks 601 - check after upgrade', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 800n
    }]);

    expect(rez.blocks[0].id).toBe(571n);
    expect(rez.blocks[rez.blocks.length - 1].id).toBe(600n);

    let archive_rez_0 = await getArchived(rez.archived_blocks[0]);
    expect(archive_rez_0.blocks[0].id).toBe(0n);
    expect(archive_rez_0.blocks[archive_rez_0.blocks.length - 1].id).toBe(119n);

    let archive_rez_1 = await getArchived(rez.archived_blocks[1]);
    expect(archive_rez_1.blocks[0].id).toBe(120n);
    expect(archive_rez_1.blocks[archive_rez_1.blocks.length - 1].id).toBe(239n);

    let archive_rez_2 = await getArchived(rez.archived_blocks[2]);
    expect(archive_rez_2.blocks[0].id).toBe(240n);
    expect(archive_rez_2.blocks[archive_rez_2.blocks.length - 1].id).toBe(359n);

    let archive_rez_3 = await getArchived(rez.archived_blocks[3]);
    expect(archive_rez_3.blocks[0].id).toBe(360n);
    expect(archive_rez_3.blocks[archive_rez_3.blocks.length - 1].id).toBe(479n);

    let archive_rez_4 = await getArchived(rez.archived_blocks[4]);
    expect(archive_rez_4.blocks[0].id).toBe(480n);
    expect(archive_rez_4.blocks[archive_rez_4.blocks.length - 1].id).toBe(570n);


    expect(data_before_upgrade).toEqual(rez);
    expect(data_before_upgrade_archive_0).toEqual(archive_rez_0);
    expect(data_before_upgrade_archive_1).toEqual(archive_rez_1);
    expect(data_before_upgrade_archive_2).toEqual(archive_rez_2);
    expect(data_before_upgrade_archive_3).toEqual(archive_rez_3);
    expect(data_before_upgrade_archive_4).toEqual(archive_rez_4);

  });


  it("Check archive canister cycle balance", async () => {
    let archives = await can.icrc3_get_archives({ from: [] });
    for (let i = 0; i < archives.length; i++) {
      let cyclesBalance = await pic.getCyclesBalance(archives[i].canister_id);
      expect(cyclesBalance).toBeGreaterThan(1_800_000_000_000);

    }

  });

  it("Check canister controllers", async () => {

    //[wudoi-4syvu-ai4px-bmcck-k5dw4-yau2x-d5pfg-bfvod-iod5o-4j6ep-uqe, ydl4r-asr5o-7axs3-tshas-4xugy-bvg4x-ixnjd-6qex3-guw6d-5pahc-oqe]; 
    let settings = await mgr.canister_status({ canister_id: canCanisterId });

    expect(toState(settings.settings.controllers)).toContain("2vxsx-fae");

    let archives = await can.icrc3_get_archives({ from: [] });

    for (let i = 0; i < archives.length; i++) {
      // mgr.setIdentity(jo);
      // let aset = await mgr.canister_status({canister_id: archives[i].canister_id});
      if (archives[i].canister_id.toText() == canCanisterId.toText()) continue;
      let aset = await mgr.canister_status({ canister_id: archives[i].canister_id });
      // let aset = await can.get_canister_settings(archives[i].canister_id);
      let controllers = toState(aset.settings.controllers);

      expect(controllers).toContain(jo.getPrincipal().toText());
      expect(controllers).toContain(bob.getPrincipal().toText());
      expect(controllers).toContain(canCanisterId.toText());
    }

  });


  it("stopped_archive: Stop archive canisters", async () => {
    let archives = await can.icrc3_get_archives({ from: [] });
    for (let i = 0; i < archives.length; i++) {
      if (archives[i].canister_id.toText() == canCanisterId.toText()) continue;

      await pic.stopCanister({ canisterId: archives[i].canister_id });
    }

  });


  it("stopped_archive: dispatch 300 actions in 1 call", async () => {
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
    expect(toState(r[0]).Ok).toBe("602");
    await passTime(20);
  });

  it('stopped_archive: icrc3_get_blocks ', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 1200n
    }]);
    let srez = toState(rez);
    expect(srez.log_length).toBe("901");
    expect(srez.blocks.length).toBe(330);
    expect(srez.archived_blocks.length).toBe(5);
    
  });

  it("stopped_archive: start archive canisters", async () => {
    let archives = await can.icrc3_get_archives({ from: [] });
    for (let i = 0; i < archives.length; i++) {
      if (archives[i].canister_id.toText() == canCanisterId.toText()) continue;

      await pic.startCanister({ canisterId: archives[i].canister_id });
    }
    await passTime(10);
  });

  it("stopped_archive: dispatch 1 action to trigger archival", async () => {

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
    await passTime(30);
    expect(toState(r[0]).Ok).toBe("902");
    
  });

  it('stopped_archive: icrc3_get_blocks after start - to see if archival resumes properly ', async () => {
    
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 1200n
    }]);
    let srez = toState(rez);
    expect(srez.log_length).toBe("902");
    expect(srez.blocks.length).toBe(62);
    expect(srez.archived_blocks.length).toBe(7);
    
  });



  it('stopped_archive: icrc3_get_blocks - check sequence', async () => {
    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 900n
    }]);

    let srez = toState(rez);
    let should_be = [
      [ { start: '0', length: '120' } ],
      [ { start: '120', length: '120' } ],
      [ { start: '240', length: '120' } ],
      [ { start: '360', length: '120' } ],
      [ { start: '480', length: '120' } ],
      [ { start: '600', length: '120' } ],
      [ { start: '720', length: '120' } ]
    ];
    
    let is = srez.archived_blocks.map((x:any) => (x.args));

    expect(is).toEqual(should_be);

  });



  it("Test memory leak after dispatching many actions", async () => {
    for (let j = 0; j < 50; j++) {

      let settings = await mgr.canister_status({ canister_id: canCanisterId });
      expect(settings.memory_size).toBeLessThan(99439968n);
      let r = await can.dispatch(Array.from({ length: 1000 }, () => ({
        ts: 12340n,
        created_at_time: 1721045569580000n,
        memo: [0, 1, 2, 3, 4],
        caller: Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"),
        fee: 1000n,
        payload: {
          swap: { amt: 123456n }
        }
      })));
        
      expect(toState(r[0]).Ok).toBe(""+(903+j*1000));

      await passTime(20);
    };

    let rez = await can.icrc3_get_blocks([{
      start: 0n,
      length: 30000n
    }]);

    let srez = toState(rez);
    expect(srez.archived_blocks.length).toBe(250);

  }, 160000);

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