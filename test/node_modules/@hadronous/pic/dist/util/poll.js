"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.poll = void 0;
const DEFAULT_POLL_INTERVAL_MS = 20;
const DEFAULT_POLL_TIMEOUT_MS = 5_000;
async function poll(cb, options) {
    const intervalMs = options?.intervalMs ?? DEFAULT_POLL_INTERVAL_MS;
    const timeoutMs = options?.timeoutMs ?? DEFAULT_POLL_TIMEOUT_MS;
    const startTimeMs = Date.now();
    return new Promise((resolve, reject) => {
        async function runPoll() {
            const currentTimeMs = Date.now();
            try {
                const result = await cb();
                clearInterval(interval);
                return resolve(result);
            }
            catch (e) {
                if (currentTimeMs - startTimeMs >= timeoutMs) {
                    clearInterval(interval);
                    return reject(e);
                }
            }
        }
        const interval = setInterval(runPoll, intervalMs);
    });
}
exports.poll = poll;
//# sourceMappingURL=poll.js.map