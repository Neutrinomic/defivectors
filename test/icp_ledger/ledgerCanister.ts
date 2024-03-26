import { resolve } from 'node:path';
import { PocketIc } from '@hadronous/pic';
import { _SERVICE as ICPLedgerService, idlFactory, init, LedgerCanisterPayload } from './ledger.idl';
import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';
import { AccountIdentifier } from "@dfinity/ledger-icp";

const WASM_PATH = resolve(__dirname, "./ledger.wasm");



export async function ICPLedger(pic: PocketIc, me:Principal, subnet:Principal | undefined) {
    let me_address = AccountIdentifier.fromPrincipal({
        principal: me,
        // subAccount: null,
      }).toHex();
      
    let ledger_args:LedgerCanisterPayload = {
        Init: {
            'send_whitelist' : [],
            'token_symbol' : ["tICP"],
            'transfer_fee' :[{e8s: 10000n}],
            'minting_account' : me_address,
            'maximum_number_of_accounts' : [],
            'accounts_overflow_trim_quantity' : [],
            'transaction_window' : [],
            'max_message_size_bytes' : [],
            'icrc1_minting_account' : [{owner: me, subaccount: []}],
            'archive_options' : [],
            'initial_values' : [[me_address, {e8s: 100000000000n}]],
            'token_name' : ["ICP Test Coin"],
            'feature_flags' : [],
        },
    };

    const fixture = await pic.setupCanister<ICPLedgerService>({
        idlFactory,
        wasm: WASM_PATH,
        arg: IDL.encode(init({IDL}), [ledger_args]),
        ...subnet?{targetSubnetId: subnet}:{},
    });

    return fixture;
};


export { ICPLedgerService };