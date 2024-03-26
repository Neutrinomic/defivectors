/** @module CanisterStatus */
import { Principal } from '@dfinity/principal';
import { HttpAgent } from '../agent/http';
import { CreateCertificateOptions } from '../certificate';
import { DerEncodedPublicKey } from '..';
/**
 * Represents the useful information about a subnet
 * @param {string} subnetId the principal id of the canister's subnet
 * @param {string[]} nodeKeys the keys of the individual nodes in the subnet
 */
export declare type SubnetStatus = {
    subnetId: string;
    nodeKeys: Map<string, DerEncodedPublicKey>;
    metrics?: {
        num_canisters: bigint;
        canister_state_bytes: bigint;
        consumed_cycles_total: {
            current: bigint;
            deleted: bigint;
        };
        update_transactions_total: bigint;
    };
};
/**
 * Types of an entry on the canisterStatus map.
 * An entry of null indicates that the request failed, due to lack of permissions or the result being missing.
 */
export declare type Status = string | ArrayBuffer | Date | ArrayBuffer[] | Principal[] | SubnetStatus | bigint | null;
/**
 * Interface to define a custom path. Nested paths will be represented as individual buffers, and can be created from text using TextEncoder.
 * @param {string} key the key to use to access the returned value in the canisterStatus map
 * @param {ArrayBuffer[]} path the path to the desired value, represented as an array of buffers
 * @param {string} decodeStrategy the strategy to use to decode the returned value
 */
export declare class CustomPath implements CustomPath {
    key: string;
    path: ArrayBuffer[] | string;
    decodeStrategy: 'cbor' | 'hex' | 'leb128' | 'utf-8' | 'raw';
    constructor(key: string, path: ArrayBuffer[] | string, decodeStrategy: 'cbor' | 'hex' | 'leb128' | 'utf-8' | 'raw');
}
/**
 * @deprecated Use {@link CustomPath} instead
 * @param {string} key the key to use to access the returned value in the canisterStatus map
 * @param {string} path the path to the desired value, represented as a string
 * @param {string} decodeStrategy the strategy to use to decode the returned value
 */
export interface MetaData {
    kind: 'metadata';
    key: string;
    path: string | ArrayBuffer;
    decodeStrategy: 'cbor' | 'hex' | 'leb128' | 'utf-8' | 'raw';
}
/**
 * Pre-configured fields for canister status paths
 */
export declare type Path = 'time' | 'controllers' | 'subnet' | 'module_hash' | 'candid' | MetaData | CustomPath;
export declare type StatusMap = Map<Path | string, Status>;
export declare type CanisterStatusOptions = {
    canisterId: Principal;
    agent: HttpAgent;
    paths?: Path[] | Set<Path>;
    blsVerify?: CreateCertificateOptions['blsVerify'];
};
/**
 * Request information in the request_status state tree for a given canister.
 * Can be used to request information about the canister's controllers, time, module hash, candid interface, and more.
 * @param {CanisterStatusOptions} options {@link CanisterStatusOptions}
 * @param {CanisterStatusOptions['canisterId']} options.canisterId {@link Principal}
 * @param {CanisterStatusOptions['agent']} options.agent {@link HttpAgent} optional authenticated agent to use to make the canister request. Useful for accessing private metadata under icp:private
 * @param {CanisterStatusOptions['paths']} options.paths {@link Path[]}
 * @returns {Status} object populated with data from the requested paths
 * @example
 * const status = await canisterStatus({
 *   paths: ['controllers', 'candid'],
 *   ...options
 * });
 *
 * const controllers = status.get('controllers');
 */
export declare const request: (options: {
    canisterId: Principal;
    agent: HttpAgent;
    paths?: Path[] | Set<Path>;
}) => Promise<StatusMap>;
export declare const fetchNodeKeys: (certificate: ArrayBuffer, canisterId: Principal, root_key?: ArrayBuffer | Uint8Array) => SubnetStatus;
export declare const encodePath: (path: Path, canisterId: Principal) => ArrayBuffer[];
