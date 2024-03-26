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

    let aggregatorId: Principal;
    let lBTCid: Principal;
    let lICPid: Principal;
    let lNTNid: Principal;
    let vectorid : Principal;

    const jo = createIdentity('superSecretAlicePassword');
    const bob = createIdentity('superSecretBobPassword');
  
    beforeAll(async () => {
      // console.log(`Jo Principal: ${jo.getPrincipal().toText()}`);
      // console.log(`Bob Principal: ${bob.getPrincipal().toText()}`);

      pic = await PocketIc.create({sns:true});

      // Aggregator
      const aggrfixture = await MockAggregator(pic, pic.getSnsSubnet()?.id);
      aggregator = aggrfixture.actor;
      aggregatorId = aggrfixture.canisterId;

      // BTC Ledger
      const ledgerfixture = await ICRCLedger(pic, jo.getPrincipal(), pic.getSnsSubnet()?.id);
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
        

    });
  
    afterAll(async () => {
      await pic.tearDown();
    });
  
    it(`Check BTC (minter) balance`  , async () => {
      const result = await lBTC.icrc1_balance_of({owner: jo.getPrincipal(), subaccount: []});
      expect(toState(result)).toBe("100000000000")
    });


    it(`Check ICP (minter) balance`  , async () => {
      const result = await lICP.icrc1_balance_of({owner: jo.getPrincipal(), subaccount: []});
      expect(toState(result)).toBe("100000000000")
    });

    async function passTime(n:number) {
      for (let i=0; i<n; i++) {
        await pic.advanceTime(3*1000);
        await pic.tick(2);
      }
    }

});
