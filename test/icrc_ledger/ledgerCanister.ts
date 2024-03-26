import { resolve } from 'node:path';
import { PocketIc } from '@hadronous/pic';
import { _SERVICE as ICRCLedgerService, idlFactory, init, LedgerArg } from './ledger.idl';
import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';

const WASM_PATH = resolve(__dirname, "./ledger.wasm");

export async function ICRCLedger(pic: PocketIc, me:Principal, subnet:Principal | undefined) {
   
    let ledger_args:LedgerArg = {
        Init: {
            minting_account: {
                owner: me,
                subaccount: []
            },
            fee_collector_account: [{ owner: me, subaccount:[] }],
            transfer_fee: 10000n,
            decimals: [8],
            token_symbol: "tCOIN",
            token_name: "Test Coin",
            metadata: [],
            initial_balances: [[{ owner: me, subaccount:[] }, 100000000000n]],
            archive_options: {
                num_blocks_to_archive: 10000n,
                trigger_threshold: 9000n,
                controller_id: me,
                max_transactions_per_response: [],
                max_message_size_bytes: [],
                cycles_for_archive_creation: [],
                node_max_memory_size_bytes: [],
            },
            maximum_number_of_accounts: [],
            accounts_overflow_trim_quantity: [],
            max_memo_length: [],
            feature_flags: [{ icrc2: true }],            
        },
    };

    const fixture = await pic.setupCanister<ICRCLedgerService>({
        idlFactory,
        wasm: WASM_PATH,
        arg: IDL.encode(init({IDL}), [ledger_args]),
        ...subnet?{targetSubnetId: subnet}:{},
    });

    return fixture;
};


export { ICRCLedgerService };