import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';


import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
import {ICPLedgerService, ICPLedger} from "./icp_ledger/ledgerCanister";
import {MockAggregatorService, MockAggregator} from "./mock_aggregator";
import {MainService, Main, MainInitArg, MainIdlFactory} from "./main_canister";
import {RootService, Root, RootInitArg, VectorInitArg, RootUpgrade} from "./root_canister";

//@ts-ignore
import {toState} from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState




describe('Root', () => {
    let pic: PocketIc;
    let aggregator: Actor<MockAggregatorService>;
    let lBTC: Actor<ICRCLedgerService>;
    let lICP: Actor<ICPLedgerService>;
    let lNTN: Actor<ICRCLedgerService>;
    let root: Actor<RootService>;

    let simPrincipal = Principal.fromText("aojy2-p2wmt-4pvbt-rslzv-2clzy-n7t2s-7u7dd-xw6op-zk6kx-vv5ju-lae");
    let aggregatorId: Principal;
    let lBTCid: Principal;
    let lICPid: Principal;
    let lNTNid: Principal;
    let rootid: Principal;


    beforeAll(async () => {
      // console.log(`Jo Principal: ${jo.getPrincipal().toText()}`);
      // console.log(`Bob Principal: ${bob.getPrincipal().toText()}`);

      pic = await PocketIc.create({sns:true});

      // Mock Aggregator
      const aggrfixture = await MockAggregator(pic, pic.getSnsSubnet()?.id);
      aggregator = aggrfixture.actor;
      aggregatorId = aggrfixture.canisterId;

      // BTC Ledger
      const ledgerfixture = await ICRCLedger(pic, simPrincipal, pic.getSnsSubnet()?.id, 10n);
      lBTC = ledgerfixture.actor;
      lBTCid = ledgerfixture.canisterId;
 
      // ICP Ledger
      const lf = await ICPLedger(pic, simPrincipal, pic.getSnsSubnet()?.id);
      lICP = lf.actor;
      lICPid = lf.canisterId;
 
      // NTN Ledger
      const nf = await ICRCLedger(pic, simPrincipal, pic.getSnsSubnet()?.id);
      lNTN = nf.actor;
      lNTNid = nf.canisterId;

      // DeFi Vector
      let arg : RootInitArg = {
        NTN_ledger_id: lNTNid,
        ICP_ledger_id: lICPid,
        DEFI_AGGREGATOR: aggregatorId,
        };



      const mf = await Root(pic, undefined, [arg]);
      root = mf.actor;
      rootid = mf.canisterId;

      lBTC.setPrincipal(simPrincipal);
      lICP.setPrincipal(simPrincipal);
      // root.setPrincipal(simPrincipal);
    });

    it(`Check BTC (minter) balance`  , async () => {
      const result = await lBTC.icrc1_balance_of({owner: simPrincipal, subaccount: []});
      expect(toState(result)).toBe("100000000000")
    });


    it(`Check ICP (minter) balance`  , async () => {
      const result = await lICP.icrc1_balance_of({owner: simPrincipal, subaccount: []});
      expect(toState(result)).toBe("100000000000")
    });


    it(`Check NTN (minter) balance`  , async () => {
      const result = await lNTN.icrc1_balance_of({owner: simPrincipal, subaccount: []});
      expect(toState(result)).toBe("100000000000")
    });

    it(`Check if mock aggregator is working`, async () => {

      let result = await aggregator.get_latest_extended();
      expect(result.length).toBe(3);
      expect(result[0].rates[0].rate).toBe(67028.989359261) // BTC
      expect(result[1].rates[0].rate).toBe(6.465749483788241) // NTN
      expect(result[2].rates[0].rate).toBe(17.378262156) // ICP

    });

    it(`Add pair`, async () => {
      await passTime(5); // Pass time so upgrade wont be triggered two times

      let dfv : VectorInitArg = {
        LEFT_ledger: lICPid,
        RIGHT_ledger: lBTCid,
        LEFT_aggr_id: 3n,
        RIGHT_aggr_id:1n 
      };

      let result = await root.add_pair(dfv);       

      let dfv2 : VectorInitArg = {
        LEFT_ledger: lICPid,
        RIGHT_ledger: lNTNid,
        LEFT_aggr_id: 3n,
        RIGHT_aggr_id:30n 
      };

      let result2 = await root.add_pair(dfv2);       

      await passTime(10);

      let pairs = toState(await root.list_pairs());

      expect(pairs.length).toBe(2);
      expect(pairs[0].init_args.LEFT_aggr_id).toBe("3");
      expect(pairs[0].init_args.RIGHT_aggr_id).toBe("1");

      expect(pairs[1].init_args.LEFT_aggr_id).toBe("3");
      expect(pairs[1].init_args.RIGHT_aggr_id).toBe("30");

    });

    it(`Check created vector canisters`, async () => {
      let pairs = await root.list_pairs();
      let dvec = pic.createActor<MainService>(MainIdlFactory, pairs[0].canister_id);

      let result = await dvec.rechain_stats();

      let sn = toState(await dvec.monitor_snapshot());
      let timer_0 = sn.monitor.filter((x:any) => x[1] == 0).length;
      let timer_1 = sn.monitor.filter((x:any) => x[1] == 1).length;
      let timer_2 = sn.monitor.filter((x:any) => x[1] == 2).length;
      let timer_3 = sn.monitor.filter((x:any) => x[1] == 3).length;
      let timer_4 = sn.monitor.filter((x:any) => x[1] == 4).length;

      // Check if timers inside the canister are running. Previously Motoko wasn't always starting the timers
      expect(timer_0).not.toBe(0);
      expect(timer_1).not.toBe(0);
      expect(timer_2).not.toBe(0);
      expect(timer_3).not.toBe(0);
      expect(timer_4).not.toBe(0);
    });


    it(`Check upgrades of root and pair canisters`, async () => {
      let pairs = await root.list_pairs();
      let dvec = pic.createActor<MainService>(MainIdlFactory, pairs[0].canister_id);
      let dvec_before = toState(await dvec.canister_info());
      let root_before = toState(await root.canister_info());
      await passTime(5);
      await RootUpgrade(pic, undefined, rootid);
      let root_after = toState(await root.canister_info());
      await passTime(20);
      expect(Number(root_before.last_upgrade)).toBeLessThan(Number(root_after.last_upgrade));
      let dvec_after = toState(await dvec.canister_info());


      let root_log = await root.show_log();
      expect(Number(dvec_before.last_upgrade)).toBeLessThan(Number(dvec_after.last_upgrade));

      expect(JSON.stringify(root_log).indexOf("ERR")).toBe(-1);
    });


    it(`Check if pairs persist`, async () => {
      let pairs = await root.list_pairs();
      expect(pairs.length).toBe(2);
    });


    afterAll(async () => {
      await pic.tearDown();
    });
  

    async function passTime(n:number) {
      for (let i=0; i<n; i++) {
        await pic.advanceTime(3*1000);
        await pic.tick(2);
      }
    }




});
