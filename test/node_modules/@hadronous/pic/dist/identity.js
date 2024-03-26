"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateRandomIdentity = exports.createIdentity = void 0;
const node_crypto_1 = require("node:crypto");
const bip39_1 = require("bip39");
const identity_1 = require("@dfinity/identity");
/**
 * Create an Identity from a seed phrase.
 * The seed phrase can be any arbitrary string.
 *
 * The Identity is generated deterministically from the seed phrase,
 * so subsequent calls to this function with the same seed phrase will
 * produce the same Identity.
 *
 * This is useful for tests where a persistent Identity is necessary
 * but it's easier to store the seed phrase than the Identity itself.
 *
 * @category API
 * @param seedPhrase The seed phrase to create the identity from. Can be any arbitrary string.
 * @returns An identity created from the seed phrase.
 *
 * @see [Identity](https://agent-js.icp.xyz/agent/interfaces/Identity.html)
 *
 * @example
 * ```ts
 * import { PocketIc, createIdentity } from '@hadronous/pic';
 * import { AnonymousIdentity } from '@dfinity/agent';
 * import { _SERVICE, idlFactory } from '../declarations';
 *
 * const wasmPath = resolve('..', '..', 'canister.wasm');
 *
 * const pic = await PocketIc.create();
 * const fixture = await pic.setupCanister<_SERVICE>(idlFactory, wasmPath);
 * const { actor } = fixture;
 *
 * const bob = createIdentity('SuperSecretSeedPhraseForBob');
 * actor.setIdentity(bob);
 * ```
 */
function createIdentity(seedPhrase) {
    const hash = (0, node_crypto_1.createHash)('sha256');
    hash.update(seedPhrase);
    const digest = hash.digest('hex').slice(0, 32);
    const encodedDigest = new TextEncoder().encode(digest);
    return identity_1.Ed25519KeyIdentity.generate(encodedDigest);
}
exports.createIdentity = createIdentity;
function generateMnemonic() {
    const entropy = (0, node_crypto_1.randomBytes)(16);
    return (0, bip39_1.entropyToMnemonic)(entropy);
}
/**
 * Create an Identity from a randomly generated bip39 seed phrase.
 * Subsequent calls to this function will produce different Identities
 * with an extremely low probability of collision.
 *
 * This is useful for tests where it is important to avoid conflicts arising
 * from multiple identities accessing the same canister and maintaining
 * the necessary seed phrases would become cumbersome.
 *
 * @category API
 * @returns An identity created from a random seed phrase.
 *
 * @see [Identity](https://agent-js.icp.xyz/agent/interfaces/Identity.html)
 *
 * @example
 * ```ts
 * import { PocketIc, generateRandomIdentity } from '@hadronous/pic';
 * import { AnonymousIdentity } from '@dfinity/agent';
 * import { _SERVICE, idlFactory } from '../declarations';
 *
 * const wasmPath = resolve('..', '..', 'canister.wasm');
 *
 * const pic = await PocketIc.create();
 * const fixture = await pic.setupCanister<_SERVICE>(idlFactory, wasmPath);
 * const { actor } = fixture;
 *
 * const bob = generateRandomIdentity();
 * actor.setIdentity(bob);
 * ```
 */
function generateRandomIdentity() {
    const mnemonic = generateMnemonic();
    return createIdentity(mnemonic);
}
exports.generateRandomIdentity = generateRandomIdentity;
//# sourceMappingURL=identity.js.map