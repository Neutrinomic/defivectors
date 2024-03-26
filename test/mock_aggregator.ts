import { resolve } from 'node:path';
import { PocketIc } from '@hadronous/pic';
import { _SERVICE as MockAggregatorService, idlFactory, init } from './build/mock_aggregator.idl';
import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';

const WASM_PATH = resolve(__dirname, "./build/mock_aggregator.wasm");

export async function MockAggregator(pic: PocketIc, subnet:Principal | undefined) {
   
    const fixture = await pic.setupCanister<MockAggregatorService>({
        idlFactory,
        wasm: WASM_PATH,
        //arg: IDL.encode(init({IDL}), [ledger_args]),
        ...subnet?{targetSubnetId: subnet}:{},
    });

    return fixture;
};


export { MockAggregatorService };