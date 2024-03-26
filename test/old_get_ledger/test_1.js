import icblast, {toState} from "@infu/icblast"

const log = console.log;

function ENat64(value) {
    // Assuming value is a BigInt because JavaScript's Number type cannot accurately represent
    // all Nat64 values (which are 64-bit unsigned integers).
    return [
        (value >> 56n) & 0xFFn,
        (value >> 48n) & 0xFFn,
        (value >> 40n) & 0xFFn,
        (value >> 32n) & 0xFFn,
        (value >> 24n) & 0xFFn,
        (value >> 16n) & 0xFFn,
        (value >> 8n) & 0xFFn,
        value & 0xFFn,
    ].map(n => Number(n)); // Convert BigInt to Number since Uint8Array needs numbers
}

function padArray(sourceArray, length, padding) {
    const paddedArray = new Array(length).fill(padding);
    sourceArray.forEach((element, index) => {
        paddedArray[index] = element;
    });
    return paddedArray;
}

function sa(n) {
    // Convert n to BigInt if it's not already, to handle numbers up to 64 bits
    const nBigInt = BigInt(n);
    const encoded = ENat64(nBigInt);
    const padded = padArray(encoded, 32, 0);
    return new Uint8Array(padded);
}

let local = icblast({ local: true, local_host: "http://localhost:8080" });
let can = await local("bd3sg-teaaa-aaaaa-qaaba-cai");
let ledger = await local("bnz7o-iuaaa-aaaaa-qaaaa-cai");

await can.start().then(log);

async function hashText(text) {
    // Encode the string into a Uint8Array
    const encoder = new TextEncoder();
    const data = encoder.encode(text);

    // Hash the data with SHA-256
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);

    // Convert the buffer to a hex string
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return hashHex;
}

// Hashing all balances after test.
// Replaying the history and hashing again should give the same result.

let acc = await can.accounts();
await hashText(JSON.stringify(toState(acc))).then(log);



for (let i = 0; i < acc.length; i++) {
    let [subaccount, balance] = acc[i];

    let bal_remote = await ledger.icrc1_balance_of({ owner: "bd3sg-teaaa-aaaaa-qaaba-cai", subaccount: (subaccount != "") ? subaccount : null });
    if (balance != bal_remote) {
        log({ subaccount, balance, bal_remote });
    }
}