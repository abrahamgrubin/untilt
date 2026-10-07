/**
 * Runs the post-session memory-profile summarization job in-process, off
 * the request path (the caller in routes/session.ts doesn't await it).
 *
 * This used to go through SQS to a separate worker service. At current
 * scale a second always-on service cost more than it bought, so the job
 * runs in the API process (docs/adr/0004-leave-aws.md). The trade-off: a
 * job in flight during a deploy or crash is lost rather than retried. That
 * only means one session's notes don't make it into the memory profile.
 * If that stops being acceptable, a Postgres-backed queue (e.g. pg-boss)
 * is the next step and needs no new vendor.
 */
export function enqueueSessionSummarization(sessionId: string, userId: string): void {
  import("./summarizeSession.js")
    .then(({ summarizeSessionAndUpdateProfile }) => summarizeSessionAndUpdateProfile(sessionId, userId))
    .catch((err) => console.error("session summarization job failed", err));
}
