import { AgentError } from '../../errors';
import { HttpDetailsResponse } from '../api';
export declare class AgentHTTPResponseError extends AgentError {
    readonly response: HttpDetailsResponse;
    constructor(message: string, response: HttpDetailsResponse);
}
