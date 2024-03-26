export { Ed25519KeyIdentity, Ed25519PublicKey } from './identity/ed25519';
export * from './identity/ecdsa';
export * from './identity/delegation';
export * from './identity/partial';
export { WebAuthnIdentity } from './identity/webauthn';
export { wrapDER, unwrapDER, DER_COSE_OID, ED25519_OID } from '@dfinity/agent';
/**
 * @deprecated due to size of dependencies. Use `@dfinity/identity-secp256k1` instead.
 */
export declare class Secp256k1KeyIdentity {
    constructor();
}
