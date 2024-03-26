import { Identity, PublicKey } from '@dfinity/agent';
import { Principal } from '@dfinity/principal';
/**
 * A partial delegated identity, representing a delegation chain and the public key that it targets
 */
export declare class PartialIdentity implements Identity {
    #private;
    /**
     * The raw public key of this identity.
     */
    get rawKey(): ArrayBuffer | undefined;
    /**
     * The DER-encoded public key of this identity.
     */
    get derKey(): ArrayBuffer | undefined;
    /**
     * The DER-encoded public key of this identity.
     */
    toDer(): ArrayBuffer;
    /**
     * The inner {@link PublicKey} used by this identity.
     */
    getPublicKey(): PublicKey;
    /**
     * The {@link Principal} of this identity.
     */
    getPrincipal(): Principal;
    /**
     * Required for the Identity interface, but cannot implemented for just a public key.
     */
    transformRequest(): Promise<never>;
    constructor(inner: PublicKey);
}
