export declare function exists(filePath: string): Promise<boolean>;
export declare function tmpFile(filePath: string): string;
export declare function readFileAsBytes(filePath: string): Promise<Uint8Array>;
export declare function readFileAsString(filePath: string): Promise<string>;
