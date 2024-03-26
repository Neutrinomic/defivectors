"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentHTTPResponseError = void 0;
const errors_1 = require("../../errors");
class AgentHTTPResponseError extends errors_1.AgentError {
    constructor(message, response) {
        super(message);
        this.response = response;
        this.name = this.constructor.name;
        Object.setPrototypeOf(this, new.target.prototype);
    }
}
exports.AgentHTTPResponseError = AgentHTTPResponseError;
//# sourceMappingURL=errors.js.map