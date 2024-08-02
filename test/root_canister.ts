import { resolve } from 'node:path';
import { PocketIc } from '@hadronous/pic';
import { _SERVICE as RootService, idlFactory, init, RootInitArg, ProdInitArg } from '../build/root.idl.js';
import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';

const WASM_PATH = resolve(__dirname, "./../build/root.wasm");

export async function Root(pic: PocketIc, subnet:Principal | undefined, initargs: [RootInitArg]) {
   
    const fixture = await pic.setupCanister<RootService>({
        idlFactory,
        wasm: WASM_PATH,
        arg: IDL.encode(init({IDL}), [initargs]),
        ...subnet?{targetSubnetId: subnet}:{},
    });

    return fixture;
};
export async function RootUpgrade(pic: PocketIc, subnet:Principal | undefined, id:Principal) {
    await pic.upgradeCanister({ canisterId: id, wasm: WASM_PATH, ...subnet?{targetSubnetId: subnet}:{}, arg: IDL.encode(init({ IDL }), [[]]) });

};

export { RootService,  RootInitArg, ProdInitArg as VectorInitArg};