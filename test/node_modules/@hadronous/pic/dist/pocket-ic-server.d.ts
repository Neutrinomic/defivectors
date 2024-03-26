export declare class PocketIcServer {
    private readonly serverProcess;
    private readonly url;
    private constructor();
    static start(): Promise<PocketIcServer>;
    getUrl(): string;
    stop(): void;
    private static getBinPath;
    private static assertBinExists;
}
