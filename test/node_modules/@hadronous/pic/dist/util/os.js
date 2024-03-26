"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isArm = exports.isDarwin = exports.isLinux = exports.is64Bit = void 0;
function is64Bit() {
    return process.arch === 'x64';
}
exports.is64Bit = is64Bit;
function isLinux() {
    return process.platform === 'linux';
}
exports.isLinux = isLinux;
function isDarwin() {
    return process.platform === 'darwin';
}
exports.isDarwin = isDarwin;
function isArm() {
    return process.arch === 'arm64';
}
exports.isArm = isArm;
//# sourceMappingURL=os.js.map