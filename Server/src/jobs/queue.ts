import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";

const queueUrl = process.env.SQS_QUEUE_URL;
const sqs = queueUrl ? new SQSClient({}) : null;

export interface SummarizationJob {
  type: "summarize_session";
  sessionId: string;
  userId: string;
}

/**
 * Enqueues the post-session memory-profile summarization job.
 *
 * - Production (SQS_QUEUE_URL set, provisioned by Infra/sqs.tf): sends to
 *   SQS; worker.ts (running as its own ECS service) picks it up.
 * - Local dev (no SQS_QUEUE_URL): falls back to firing the job in-process,
 *   so you can run the whole thing with just `npm run dev` and no AWS
 *   account. This was the only implementation before this step.
 */
export async function enqueueSessionSummarization(sessionId: string, userId: string): Promise<void> {
  const job: SummarizationJob = { type: "summarize_session", sessionId, userId };

  if (sqs && queueUrl) {
    await sqs.send(
      new SendMessageCommand({
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(job),
      })
    );
    return;
  }

  // Dev fallback — deliberately not awaited by the caller (see routes/session.ts).
  import("./summarizeSession.js")
    .then(({ summarizeSessionAndUpdateProfile }) => summarizeSessionAndUpdateProfile(sessionId, userId))
    .catch((err) => console.error("session summarization job failed (dev fallback)", err));
}
