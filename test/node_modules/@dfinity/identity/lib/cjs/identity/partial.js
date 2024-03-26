"use strict";
var __classPrivateFieldSet = (this && this.__classPrivateFieldSet) || function (receiver, state, value, kind, f) {
    if (kind === "m") throw new TypeError("Private method is not writable");
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a setter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot write private member to an object whose class did not declare it");
    return (kind === "a" ? f.call(receiver, value) : f ? f.value = value : state.set(receiver, value)), value;
};
var __classPrivateFieldGet = (this && this.__classPrivateFieldGet) || function (receiver, state, kind, f) {
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a getter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot read private member from an object whose class did not declare it");
    return kind === "m" ? f : kind === "a" ? f.call(receiver) : f ? f.value : state.get(receiver);
};
var _PartialIdentity_inner;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PartialIdentity = void 0;
const principal_1 = require("@dfinity/principal");
/**
 * A partial delegated identity, representing a delegation chain and the public key that it targets
 */
class PartialIdentity {
    constructor(inner) {
        _PartialIdentity_inner.set(this, void 0);
        __classPrivateFieldSet(this, _PartialIdentity_inner, inner, "f");
    }
    /**
     * The raw public key of this identity.
     */
    get rawKey() {
        return __classPrivateFieldGet(this, _PartialIdentity_inner, "f").rawKey;
    }
    /**
     * The DER-encoded public key of this identity.
     */
    get derKey() {
        return __classPrivateFieldGet(this, _PartialIdentity_inner, "f").derKey;
    }
    /**
     * The DER-encoded public key of this identity.
     */
    toDer() {
        return __classPrivateFieldGet(this, _PartialIdentity_inner, "f").toDer();
    }
    /**
     * The inner {@link PublicKey} used by this identity.
     */
    getPublicKey() {
        return __classPrivateFieldGet(this, _PartialIdentity_inner, "f");
    }
    /**
     * The {@link Principal} of this identity.
     */
    getPrincipal() {
        return principal_1.Principal.from(__classPrivateFieldGet(this, _PartialIdentity_inner, "f").rawKey);
    }
    /**
     * Required for the Identity interface, but cannot implemented for just a public key.
     */
    transformRequest() {
        return Promise.reject('Not implemented. You are attempting to use a partial identity to sign calls, but this identity only has access to the public key.To sign calls, use a DelegationIdentity instead.');
    }
}
exports.PartialIdentity = PartialIdentity;
_PartialIdentity_inner = new WeakMap();
//# sourceMappingURL=partial.js.map