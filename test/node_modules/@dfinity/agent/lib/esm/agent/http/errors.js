import { AgentError } from '../../errors';
export class AgentHTTPResponseError extends AgentError {
    constructor(message, response) {
        super(message);
        this.response = response;
        this.name = this.constructor.name;
        Object.setPrototypeOf(this, new.target.prototype);
    }
}
//# sourceMappingURL=errors.js.map