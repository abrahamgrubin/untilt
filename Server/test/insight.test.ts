import { describe, expect, it, vi, beforeEach, afterAll, beforeAll } from "vitest";
import express from "express";
import type { AddressInfo } from "node:net";
import type { Server } from "node:http";

// --- Mocks: no network, no database, no Cognito ---------------------------

const completeChat = vi.fn();
vi.mock("../src/ai/claude.js", () => ({
  MODELS: { sonnet: "sonnet-test", haiku: "haiku-test" },
  completeChat: (...args: unknown[]) => completeChat(...args),
}));

vi.mock("../src/middleware/auth.js", () => ({
  requireAuth: (req: any, _res: any, next: any) => {
    req.userId = "00000000-0000-0000-0000-000000000001";
    req.log = { info: vi.fn(), warn: vi.fn(), error: vi.fn() };
    next();
  },
}));

vi.mock("../src/db/repositories/users.js", () => ({ ensureUser: vi.fn(async () => {}) }));

const memoryProfile = { triggers: ["late-night games"], copingStrategies: ["box breathing"], pastCrisisFlags: false, tonePreferences: "" };
vi.mock("../src/db/repositories/memoryProfile.js", () => ({
  getMemoryProfile: vi.fn(async () => memoryProfile),
}));

let recentCrisis = false;
vi.mock("../src/db/repositories/crisisEvents.js", () => ({
  hasRecentCrisisEvent: vi.fn(async () => recentCrisis),
}));

const store = new Map<string, any>();
vi.mock("../src/db/repositories/dailyInsights.js", () => ({
  getDailyInsight: vi.fn(async (u: string, d: string) => store.get(`${u}|${d}`)),
  saveDailyInsight: vi.fn(async (u: string, d: string, ins: any) => {
    const k = `${u}|${d}`;
    if (!store.has(k)) store.set(k, ins);
    return store.get(k);
  }),
}));

const { buildInsightUserMessage, parseInsightCard, checkInCard, insightCardSchema, isPlausibleLocalDate } = await import("../src/ai/insight.js");
const { insightRouter } = await import("../src/routes/insight.js");

// --- Fixtures -------------------------------------------------------------

const today = new Date().toISOString().slice(0, 10);

const snapshot = {
  localDate: today,
  daysClean: 23,
  urgesLast7Days: { resisted: 3, slipped: 1 },
  urgesPrior7Days: { resisted: 5, slipped: 2 },
  hoursSinceLastUrge: 14.6,
  meditationLast7Days: { sessions: 5, minutes: 47 },
  recentMeditationTitles: ["Quick Reset", "Grounding"],
  nextMilestoneDays: 30,
};

const goodCard = {
  title: "Fewer urges this week than last",
  body: "You had 4 urges this week compared with 7 the week before, and you rode out most of them.",
  bullets: ["5 meditation sessions this week", "7 days to your 30-day milestone"],
  question: "What has felt different about the moments you got through?",
};

// --- Unit tests -----------------------------------------------------------

describe("parseInsightCard", () => {
  it("accepts a valid card, with or without code fences", () => {
    expect(parseInsightCard(JSON.stringify(goodCard))).toEqual(goodCard);
    expect(parseInsightCard("```json\n" + JSON.stringify(goodCard) + "\n```")).toEqual(goodCard);
  });

  it("rejects non-JSON and wrong shapes", () => {
    expect(parseInsightCard("Here is your insight!")).toBeUndefined();
    expect(parseInsightCard(JSON.stringify({ ...goodCard, bullets: ["a", "b", "c"] }))).toBeUndefined();
    expect(parseInsightCard(JSON.stringify({ title: "x" }))).toBeUndefined();
  });

  it("rejects the word relapse in any field", () => {
    expect(parseInsightCard(JSON.stringify({ ...goodCard, body: "One relapse doesn't define you." }))).toBeUndefined();
    expect(parseInsightCard(JSON.stringify({ ...goodCard, question: "Did you Relapsed?" }))).toBeUndefined();
  });

  it("rejects crisis language in the generated text", () => {
    expect(parseInsightCard(JSON.stringify({ ...goodCard, body: "It can feel like there is no way out." }))).toBeUndefined();
  });
});

describe("buildInsightUserMessage", () => {
  it("includes the numbers and profile, and nothing else", () => {
    const msg = buildInsightUserMessage(snapshot, memoryProfile);
    expect(msg).toContain("Days clean: 23");
    expect(msg).toContain("7 to go");
    expect(msg).toContain("3 resisted, 1 slips");
    expect(msg).toContain("Hours since the most recent urge: 15");
    expect(msg).toContain("Quick Reset; Grounding");
    expect(msg).toContain("late-night games");
  });

  it("handles a brand-new user with no activity", () => {
    const msg = buildInsightUserMessage(
      { ...snapshot, daysClean: 0, urgesLast7Days: { resisted: 0, slipped: 0 }, urgesPrior7Days: { resisted: 0, slipped: 0 },
        hoursSinceLastUrge: null, meditationLast7Days: { sessions: 0, minutes: 0 }, recentMeditationTitles: [], nextMilestoneDays: 7 },
      { triggers: [], copingStrategies: [], pastCrisisFlags: false, tonePreferences: "" }
    );
    expect(msg).toContain("No urges recorded yet");
    expect(msg).not.toContain("Recent meditation sessions");
    expect(msg).not.toContain("triggers");
  });
});

describe("isPlausibleLocalDate", () => {
  const now = new Date("2026-09-25T12:00:00Z");
  it("allows yesterday, today and tomorrow (time zones)", () => {
    expect(isPlausibleLocalDate("2026-09-24", now)).toBe(true);
    expect(isPlausibleLocalDate("2026-09-25", now)).toBe(true);
    expect(isPlausibleLocalDate("2026-09-26", now)).toBe(true);
  });
  it("rejects dates further out and impossible dates", () => {
    expect(isPlausibleLocalDate("2026-09-23", now)).toBe(false);
    expect(isPlausibleLocalDate("2027-09-25", now)).toBe(false);
    expect(isPlausibleLocalDate("2026-02-31", now)).toBe(false);
  });
});

describe("checkInCard", () => {
  it("lists the real crisis numbers and fits the card shape", () => {
    const card = checkInCard();
    expect(card.bullets.join(" ")).toContain("1-800-522-4700");
    expect(card.bullets.join(" ")).toContain("988");
    // Fixed copy, never run through parseInsightCard (whose crisis-word filter
    // is for generated text and would reject the lifeline's own name).
    expect(insightCardSchema.safeParse(card).success).toBe(true);
  });
});

// --- Route tests ----------------------------------------------------------

let server: Server;
let baseUrl: string;

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  app.use("/insight", insightRouter);
  await new Promise<void>((resolve) => {
    server = app.listen(0, () => resolve());
  });
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

afterAll(() => {
  server.close();
});

beforeEach(() => {
  store.clear();
  recentCrisis = false;
  completeChat.mockReset();
});

const post = (body: unknown) =>
  fetch(`${baseUrl}/insight`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });

describe("POST /insight", () => {
  it("generates once per day, then serves the stored card", async () => {
    completeChat.mockResolvedValue(JSON.stringify(goodCard));

    const first = await post(snapshot);
    expect(first.status).toBe(200);
    expect(await first.json()).toEqual({ localDate: today, kind: "insight", ...goodCard });

    const second = await post({ ...snapshot, daysClean: 24 });
    expect(second.status).toBe(200);
    expect((await second.json()).title).toBe(goodCard.title);
    expect(completeChat).toHaveBeenCalledTimes(1);
  });

  it("sends the persona + insight prompt and only the numeric summary", async () => {
    completeChat.mockResolvedValue(JSON.stringify(goodCard));
    await post(snapshot);
    const call = completeChat.mock.calls[0][0];
    expect(call.model).toBe("sonnet-test");
    expect(call.system).toHaveLength(2);
    expect(call.system[0].text).toContain("You are Compass");
    expect(call.messages).toHaveLength(1);
    expect(call.messages[0].content).toContain("Days clean: 23");
  });

  it("serves the fixed check-in card after a recent crisis, without calling Claude", async () => {
    recentCrisis = true;
    const res = await post(snapshot);
    const json = await res.json();
    expect(res.status).toBe(200);
    expect(json.kind).toBe("check_in");
    expect(json.bullets.join(" ")).toContain("1-800-522-4700");
    expect(json.resources.map((r: any) => r.telHref)).toEqual(["tel:+18005224700", "tel:988"]);
    expect(completeChat).not.toHaveBeenCalled();
  });

  it("returns resources only on check-in cards", async () => {
    completeChat.mockResolvedValue(JSON.stringify(goodCard));
    const json = await (await post(snapshot)).json();
    expect(json.kind).toBe("insight");
    expect(json.resources).toBeUndefined();
  });

  it("returns 503 and stores nothing when the model output is unusable", async () => {
    completeChat.mockResolvedValue("Sorry, I can't do that.");
    const res = await post(snapshot);
    expect(res.status).toBe(503);
    expect(store.size).toBe(0);

    completeChat.mockResolvedValue(JSON.stringify(goodCard));
    expect((await post(snapshot)).status).toBe(200);
  });

  it("returns 503 when the Claude call throws", async () => {
    completeChat.mockRejectedValue(new Error("overloaded"));
    expect((await post(snapshot)).status).toBe(503);
  });

  it("rejects bad snapshots", async () => {
    expect((await post({ ...snapshot, localDate: "25/09/2026" })).status).toBe(400);
    expect((await post({ ...snapshot, daysClean: -1 })).status).toBe(400);
    expect((await post({ ...snapshot, localDate: "2020-01-01" })).status).toBe(400);
    expect((await post({ ...snapshot, recentMeditationTitles: ["a", "b", "c", "d"] })).status).toBe(400);
    expect(completeChat).toHaveBeenCalledTimes(0);
  });

  it("accepts a snapshot with nil optionals omitted, as Swift sends them", async () => {
    completeChat.mockResolvedValue(JSON.stringify(goodCard));
    const { hoursSinceLastUrge, nextMilestoneDays, recentMeditationTitles, ...minimal } = snapshot;
    expect((await post(minimal)).status).toBe(200);
    expect(completeChat.mock.calls[0][0].messages[0].content).toContain("No urges recorded yet");
  });

  it("drops unknown fields so free text never reaches the prompt", async () => {
    completeChat.mockResolvedValue(JSON.stringify(goodCard));
    expect((await post({ ...snapshot, journal: "SECRET JOURNAL TEXT" })).status).toBe(200);
    expect(completeChat.mock.calls[0][0].messages[0].content).not.toContain("SECRET JOURNAL TEXT");
  });
});
