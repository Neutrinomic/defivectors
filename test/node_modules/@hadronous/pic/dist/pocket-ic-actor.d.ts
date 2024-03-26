import { IDL } from '@dfinity/candid';
import { Principal } from '@dfinity/principal';
import { Identity } from '@dfinity/agent';
import { PocketIcClient } from './pocket-ic-client';
/**
 * Typesafe method of a canister.
 *
 * @category Types
 */
export interface ActorMethod<Args extends unknown[] = unknown[], Ret = unknown> {
    (...args: Args): Promise<Ret>;
}
/**
 * Candid interface of a canister.
 *
 * @category Types
 */
export type ActorInterface = Record<string, ActorMethod>;
/**
 * A typesafe class that implements the Candid interface of a canister.
 * This is acquired by calling {@link PocketIc.setupCanister | setupCanister}
 * or {@link PocketIc.createActor | createActor}.
 *
 * @category API
 * @typeparam T The type of the {@link Actor}. Must implement {@link ActorInterface}.
 * @interface
 */
export type Actor<T = ActorInterface> = T & {
    /**
     * @ignore
     */
    new (): Actor<T>;
    /**
     * Set a Principal to be used as sender for all calls to the canister.
     *
     * @param principal The Principal to set.
     *
     * @see [Principal](https://agent-js.icp.xyz/principal/classes/Principal.html)
     *
     * @example
     * ```ts
     * import { PocketIc } from '@hadronous/pic';
     * import { Principal } from '@dfinity/principal';
     * import { _SERVICE, idlFactory } from '../declarations';
     *
     * const wasmPath = resolve('..', '..', 'canister.wasm');
     *
     * const pic = await PocketIc.create();
     * const fixture = await pic.setupCanister<_SERVICE>(idlFactory, wasmPath);
     * const { actor } = fixture;
     *
     * actor.setPrincipal(Principal.anonymous());
     * ```
     */
    setPrincipal(principal: Principal): void;
    /**
     * Set a Principal to be used as sender for all calls to the canister.
     * This is a convenience method over {@link setPrincipal} that accepts an
     * Identity and internally extracts the Principal.
     *
     * @param identity The identity to set.
     *
     * @see [Identity](https://agent-js.icp.xyz/agent/interfaces/Identity.html)
     * @see [Principal](https://agent-js.icp.xyz/principal/classes/Principal.html)
     *
     * @example
     * ```ts
     * import { PocketIc } from '@hadronous/pic';
     * import { AnonymousIdentity } from '@dfinity/agent';
     * import { _SERVICE, idlFactory } from '../declarations';
     *
     * const wasmPath = resolve('..', '..', 'canister.wasm');
     *
     * const pic = await PocketIc.create();
     * const fixture = await pic.setupCanister<_SERVICE>(idlFactory, wasmPath);
     * const { actor } = fixture;
     *
     * actor.setIdentity(new AnonymousIdentity());
     * ```
     */
    setIdentity(identity: Identity): void;
};
export declare function createActorClass<T = ActorInterface>(interfaceFactory: IDL.InterfaceFactory, canisterId: Principal, pocketIcClient: PocketIcClient): Actor<T>;
