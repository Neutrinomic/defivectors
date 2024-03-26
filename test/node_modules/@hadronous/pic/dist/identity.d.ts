import { Identity } from '@dfinity/agent';
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
export declare function createIdentity(seedPhrase: string): Identity;
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
export declare function generateRandomIdentity(): Identity;
