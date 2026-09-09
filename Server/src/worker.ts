/**
 * Worker entrypoint — a separate process/ECS service from the API
 * (Infra/ecs.tf: aws_ecs_service.worker), long-polling the SQS queue for
 * session-summarization jobs enqueued by jobs/queue.ts. Kept as its own
 * service, not a background thread in the API process, so a burst of
 * summarization work can never compete with urge-surfing request latency.
 */
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from "@aws-sdk/client-sqs";
import type { SummarizationJob } from "./jobs/queue.js";
import { summarizeSessionAndUpdateProfile } from "./jobs/summarizeSession.js";

const queueUrl = process.env.SQS_QUEUE_URL;
if (!queueUrl) {
  console.error("worker: SQS_QUEUE_URL is not set — nothing to consume, exiting.");
  process.exit(1);
}

const sqs = new SQSClient({});
let shuttingDown = false;

process.on("SIGTERM", () => {
  console.log("worker: SIGTERM received, finishing in-flight work then exiting");
  shuttingDown = true;
});

async function processMessage(body: string): Promise<void> {
  const job = JSON.parse(body) as SummarizationJob;
  if (job.type !== "summarize_session") {
    console.warn("worker: unknown job type, skipping", job);
    return;
  }
  await summarizeSessionAndUpdateProfile(job.sessionId, job.userId);
}

async function pollLoop(): Promise<void> {
  console.log("worker: polling", queueUrl);
  while (!shuttingDown) {
    const { Messages } = await sqs.send(
      new ReceiveMessageCommand({
        QueueUrl: queueUrl,
        MaxNumberOfMessages: 5,
        WaitTimeSeconds: 20, // long polling
      })
    );

    for (const message of Messages ?? []) {
      try {
        await processMessage(message.Body!);
        await sqs.send(
          new DeleteMessageCommand({ QueueUrl: queueUrl, ReceiptHandle: message.ReceiptHandle! })
        );
      } catch (err) {
        // Don't delete on failure — SQS redelivers after the visibility
        // timeout, and after 5 attempts (Infra/sqs.tf redrive_policy) it
        // lands in the dead-letter queue for investigation, rather than
        // being silently dropped.
        console.error("worker: job failed, leaving for retry/DLQ", err);
      }
    }
  }
}

pollLoop().catch((err) => {
  console.error("worker: poll loop crashed", err);
  process.exit(1);
});
