import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';


import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
import {ICPLedgerService, ICPLedger} from "./icp_ledger/ledgerCanister";
import {MockAggregatorService, MockAggregator} from "./mock_aggregator";
import {MainService, Main, MainInitArg} from "./main_canister";

//@ts-ignore
import {toState} from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState




describe('Basic', () => {
    let pic: PocketIc;
    let aggregator: Actor<MockAggregatorService>;
    let lBTC: Actor<ICRCLedgerService>;
    let lICP: Actor<ICPLedgerService>;
    let lNTN: Actor<ICRCLedgerService>;
    let vector: Actor<MainService>;

    let simPrincipal = Principal.fromText("aojy2-p2wmt-4pvbt-rslzv-2clzy-n7t2s-7u7dd-xw6op-zk6kx-vv5ju-lae");
    let aggregatorId: Principal;
    let lBTCid: Principal;
    let lICPid: Principal;
    let lNTNid: Principal;
    let vectorid : Principal;


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
      let arg : MainInitArg = {
        NTN_ledger_id: lNTNid,
        ICP_ledger_id: lICPid,
        LEFT_ledger: lICPid,
        RIGHT_ledger: lBTCid,
        DEFI_AGGREGATOR: aggregatorId,
        LEFT_aggr_id: 3n,
        RIGHT_aggr_id:1n 
        };

      const mf = await Main(pic, pic.getSnsSubnet()?.id, arg);
      vector = mf.actor;
      vectorid = mf.canisterId;

      lBTC.setPrincipal(simPrincipal);
      lICP.setPrincipal(simPrincipal);
      vector.setPrincipal(simPrincipal);
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

    it(`Check if indexing works`, async () => {
      await passTime(10);
      let result = await vector.monitor_snapshot();
      expect(result.indexed_left).toBe(1n);
      expect(result.indexed_right).toBe(1n);
      let subaccount = new Array(32).fill(1);

      await lICP.icrc1_transfer({to: {owner:simPrincipal, subaccount:[subaccount]}, amount: 1000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});

      await lBTC.icrc1_transfer({to: {owner:simPrincipal, subaccount:[subaccount]}, amount: 1000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});
      
      await passTime(5);
      let result2 = await vector.monitor_snapshot();
      expect(result2.indexed_left).toBe(2n);
      expect(result2.indexed_right).toBe(2n);

      for (let i=0;i < 100; i++) {
         await lICP.icrc1_transfer({to: {owner:simPrincipal, subaccount:[subaccount]}, amount: 100000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});
         await lBTC.icrc1_transfer({to: {owner:simPrincipal, subaccount:[subaccount]}, amount: 1000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});
      };
      await passTime(5);
      let result3 = await vector.monitor_snapshot();

      expect(result3.indexed_left).toBe(102n);
      expect(result3.indexed_right).toBe(102n);
    },60000);
    

    it(`Create two vectors which are supposed to match`, async () => {
      
      const result = await vector.create_vector({
        algo: {
          v1:{
            interval_release_usd: 1000,
            interval_seconds: 2,
            max: 5000,
            max_tradable_usd: 10000,
            multiplier: 1.01,
            multiplier_wiggle: 0.005,
            multiplier_wiggle_seconds: 10
          }
        },
        destination: {
          address: [],
          ledger: lBTCid,
        },
        source: {
          address: [],
          ledger: lICPid
        }
      }, {icp: null});

      expect(result.ok).toBe(0);

      const result1 = await vector.create_vector({
        algo: {
          v1:{
            interval_release_usd: 1000,
            interval_seconds: 2,
            max: 1,
            max_tradable_usd: 1000,
            multiplier: 1.01,
            multiplier_wiggle: 0.005,
            multiplier_wiggle_seconds: 10
          }
        },
        destination: {
          address: [],
          ledger: lICPid,
        },
        source: {
          address: [],
          ledger: lBTCid
        }
      }, {icp: null});
 
      expect(result1.ok).toBe(1);

      await passTime(1);
    });


    it(`Send tokens to vector source addresses`, async () => {

      let v1 = await vector.get_vector(0n);

      await lICP.icrc1_transfer({to: v1[0].source.address, amount: 100000000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});

      let b1 = await lICP.icrc1_balance_of(v1[0].source.address);

      expect(b1).toBe(100000000000n);

      let v2 = await vector.get_vector(1n);
      await lBTC.icrc1_transfer({to: v2[0].source.address, amount: 100000000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});

      let b2 = await lBTC.icrc1_balance_of(v2[0].source.address);

      expect(b2).toBe(100000000000n);

      await passTime(40);

    }, 10000);

    it(`Check if trades are working`, async () => {
      
      let v1 = await vector.get_vector(0n);
      let v2 = await vector.get_vector(1n);
      
      expect(v1[0].destination_balance).not.toBe(0n);
      expect(v2[0].destination_balance).not.toBe(0n);

      let d1 = await lBTC.icrc1_balance_of(v1[0].destination.address);
      let d2 = await lICP.icrc1_balance_of(v2[0].destination.address);

      expect(d1).not.toBe(0n);
      expect(d2).not.toBe(0n);

      // let rate = Number(d1)/Number(d2);

    });

    it("Check if balances are synchronized with ledgers", async () => {
      let v1 = await vector.get_vector(0n);
      let v2 = await vector.get_vector(1n);

      let s1 = await lICP.icrc1_balance_of(v1[0].source.address);
      let s2 = await lBTC.icrc1_balance_of(v2[0].source.address);

      expect(s1).toBe(v1[0].source_balance);
      expect(s2).toBe(v2[0].source_balance);

      let d1 = await lBTC.icrc1_balance_of(v1[0].destination.address);
      let d2 = await lICP.icrc1_balance_of(v2[0].destination.address);

      expect(d1).toBe(v1[0].destination_balance);
      expect(d2).toBe(v2[0].destination_balance);

    });

    it("Check vector events log", async () => {
      let e1 = await vector.get_vector_events({id:0, start:0n, length:10n});
      // console.log(JSON.stringify(toState(e1), null, 2));

      expect(e1.ok.total).toBe(73n);
      expect(e1.ok.entries[0][1][0].kind.source_in.amount).toBe(100000000000n);
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
