import { resolve } from 'node:path';
import { PocketIc } from '@hadronous/pic';
import { _SERVICE as MainService, idlFactory, init, InitArg } from '../build/main.idl.js';
import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';

const WASM_PATH = resolve(__dirname, "./../build/main.wasm");

export async function Main(pic: PocketIc, subnet:Principal | undefined, initargs: InitArg) {
   
    const fixture = await pic.setupCanister<MainService>({
        idlFactory,
        wasm: WASM_PATH,
        arg: IDL.encode(init({IDL}), [initargs]),
        ...subnet?{targetSubnetId: subnet}:{},
    });

    return fixture;
};


export { MainService, InitArg as MainInitArg };