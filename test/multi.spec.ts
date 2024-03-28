import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';

import { mock, clear } from "jest-random-mock";

import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
import {ICPLedgerService, ICPLedger} from "./icp_ledger/ledgerCanister";
import {MockAggregatorService, MockAggregator} from "./mock_aggregator";
import {MainService, Main, MainInitArg} from "./main_canister";

//@ts-ignore
import {toState} from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState




describe('Multi', () => {
    let pic: PocketIc;
    let aggregator: Actor<MockAggregatorService>;
    let lBTC: Actor<ICRCLedgerService>;
    let lICP: Actor<ICPLedgerService>;
    let lNTN: Actor<ICRCLedgerService>;
    let vector: Actor<MainService>;

    let aggregatorId: Principal;
    let lBTCid: Principal;
    let lICPid: Principal;
    let lNTNid: Principal;
    let vectorid : Principal;

    const jo = createIdentity('superSecretAlicePassword');
    const bob = createIdentity('superSecretBobPassword');
    beforeEach(() => {
      mock(); // makes Math.random deterministic
    });
    afterEach(() => {
      clear();
    });
    beforeAll(async () => {
      // console.log(`Jo Principal: ${jo.getPrincipal().toText()}`);
      // console.log(`Bob Principal: ${bob.getPrincipal().toText()}`);

      pic = await PocketIc.create({sns:true});

      // Mock Aggregator
      const aggrfixture = await MockAggregator(pic, pic.getSnsSubnet()?.id);
      aggregator = aggrfixture.actor;
      aggregatorId = aggrfixture.canisterId;

      // BTC Ledger
      const ledgerfixture = await ICRCLedger(pic, jo.getPrincipal(), pic.getSnsSubnet()?.id, 10n);
      lBTC = ledgerfixture.actor;
      lBTCid = ledgerfixture.canisterId;
 
      // ICP Ledger
      const lf = await ICPLedger(pic, jo.getPrincipal(), pic.getSnsSubnet()?.id);
      lICP = lf.actor;
      lICPid = lf.canisterId;
 
      // NTN Ledger
      const nf = await ICRCLedger(pic, jo.getPrincipal(), pic.getSnsSubnet()?.id);
      lNTN = nf.actor;
      lNTNid = nf.canisterId;
 
      // DeFi Vector
      let arg : MainInitArg = {
        NTN_ledger_id: lNTNid,
        ICP_ledger_id: lICPid,
        LEFT_ledger: lICPid,
        RIGHT_ledger: lBTCid,
        DEFI_AGGREGATOR: aggregatorId
        };

      const mf = await Main(pic, pic.getSnsSubnet()?.id, arg);
      vector = mf.actor;
      vectorid = mf.canisterId;

      lICP.setIdentity(jo);
      lBTC.setIdentity(jo);
      lNTN.setIdentity(jo);
      vector.setIdentity(jo);

    });

 
    

    it(`Create 1000 vectors with different prices`, async () => {
      await passTime(10);

      for (let i=0; i< 500; i++) {
      const result = await vector.create_vector({
        algo: {
          v1:{
            interval_release_usd: randInt(50, 100),
            interval_seconds: 2,
            max: 5000,
            max_tradable_usd: 100,
            multiplier: 1.00 + randInt(1,100) * 0.001,
            multiplier_wiggle: 0.005 * randInt(1, 3),
            multiplier_wiggle_seconds: randInt(5, 20)
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
 
      expect(result.ok).toBeDefined();

      const result1 = await vector.create_vector({
        algo: {
          v1:{
            interval_release_usd: randInt(50, 100),
            interval_seconds: 2,
            max: 1,
            max_tradable_usd: 100,
            multiplier: 1.01 + randInt(1,100) * 0.001,
            multiplier_wiggle: 0.005 * randInt(1, 3),
            multiplier_wiggle_seconds: randInt(5, 20)
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
 
      expect(result1.ok).toBeDefined();
      };

      await passTime(1);

    }, 60000);


    it(`Send tokens to vector source addresses`, async () => {

      for (let i=0; i< 300; i++) {
        let vec = await vector.get_vector(i);

        if (vec[0].source.ledger_symbol == "tICP") {
         let r = await lICP.icrc1_transfer({to: vec[0].source.address, amount: 100000000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});
         expect("Ok" in r).toBe(true);
        } else {
         let r = await lBTC.icrc1_transfer({to: vec[0].source.address, amount: 100000000000n, fee: [], memo: [], created_at_time:[], from_subaccount:[]});
         expect("Ok" in r).toBe(true);
        }
      };

    }, 30000);


    it(`Check if trades are working`, async () => {

      await passTime(20); // will allow vectors to trade

      let v1 = await vector.get_vector(0n);
      let v2 = await vector.get_vector(1n);
      
      expect(v1[0].destination_balance).not.toBe(0n);
      expect(v2[0].destination_balance).not.toBe(0n);

      let d1 = await lBTC.icrc1_balance_of(v1[0].destination.address);
      let d2 = await lICP.icrc1_balance_of(v2[0].destination.address);

      expect(d1).not.toBe(0n);
      expect(d2).not.toBe(0n);

      let rate = Number(d1)/Number(d2);
      console.log(rate);

    }, 10000);

    it(`Check if trades are working`, async () => {
      
      for (let i=0; i< 20; i++) {
        let vec = await vector.get_vector(0n);
        expect(vec[0].destination_balance).not.toBe(0n);
      };
      
    });

    it("Check events log snapshot to verify algorithms didn't change", async () => {
      // Retrieves the first 3000 events and checks if the state is the same as the snapshot
      // If there is an error here, it means the algorithms have changed
      
      let elog = await vector.get_vector_events({id:0, start:0n, length:147n});

      expect(toState(elog)).toMatchSnapshot()

      let elog_all_1 = await vector.get_events({start:0n, length:1000n});

      expect(toState(elog_all_1)).toMatchSnapshot()

      let elog_all_2 = await vector.get_events({start:1000n, length:1000n});

      expect(toState(elog_all_2)).toMatchSnapshot()

      let elog_all_3 = await vector.get_events({start:2000n, length:1000n});

      expect(toState(elog_all_3)).toMatchSnapshot()
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



function randInt(min:number, max:number) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}