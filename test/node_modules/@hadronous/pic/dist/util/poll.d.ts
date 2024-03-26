export interface PollOptions {
    intervalMs?: number;
    timeoutMs?: number;
}
export declare function poll<T extends (...args: any) => any>(cb: T, options?: PollOptions): Promise<ReturnType<T>>;
