"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.readFileAsString = exports.readFileAsBytes = exports.tmpFile = exports.exists = void 0;
const promises_1 = require("node:fs/promises");
const node_path_1 = require("node:path");
const node_os_1 = require("node:os");
async function exists(filePath) {
    try {
        await (0, promises_1.access)(filePath, promises_1.constants.F_OK);
        return true;
    }
    catch (e) {
        return false;
    }
}
exports.exists = exists;
function tmpFile(filePath) {
    return (0, node_path_1.resolve)((0, node_os_1.tmpdir)(), filePath);
}
exports.tmpFile = tmpFile;
async function readFileAsBytes(filePath) {
    const buffer = await (0, promises_1.readFile)(filePath);
    return Uint8Array.from(buffer);
}
exports.readFileAsBytes = readFileAsBytes;
async function readFileAsString(filePath) {
    return await (0, promises_1.readFile)(filePath, { encoding: 'utf-8' });
}
exports.readFileAsString = readFileAsString;
//# sourceMappingURL=fs.js.map