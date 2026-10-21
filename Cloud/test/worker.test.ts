import { env, runInDurableObject } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { base64Encode } from "../src/bytes";
import type { Env } from "../src/env";
import worker, { quotaDay } from "../src/index";
import { Phone, call, sse } from "./client";

const chat = { messages: [{ role: "user", content: "Make egg fried rice." }] };
const ideas = {
  requestId: "set-1",
  request: "Something easy when I'm tired",
  ingredients: ["eggs", "rice"],
  tools: ["frying pan"],
  ideas: [{ title: "Egg fried rice", summary: "One pan, 15 minutes" }, { title: "Rice porridge" }],
};

function clef(choice: string, fails = false) {
  return vi.fn(async (_model: string, _input: object) => {
    if (fails) throw new Error("clef is down");
    return {
      model: "clef-flash",
      answers: { pick: { type: "choice", choice, confidence: 0.8, probabilities: { idea_1: 0.1, idea_2: 0.9 } } },
      usage: { input_tokens: 1, output_tokens: 1 },
    };
  });
}

afterEach(() => vi.restoreAllMocks());

describe("routing", () => {
  it("serves health, redirects home, and rejects the rest", async () => {
    expect((await call(new Request("https://plates.test/health"))).status).toBe(200);
    const home = await call(new Request("https://plates.test/"));
    expect(home.status).toBe(302);
    expect(home.headers.get("Location")).toBe("https://atelier.ktgk.app/#plates");
    expect((await call(new Request("https://plates.test/v1/chat/completions"))).status).toBe(405);
    expect((await call(new Request("https://plates.test/v1/nothing", { method: "POST" }))).status).toBe(404);
  });

  it("says so when a setting is missing", async () => {
    const request = new Request("https://plates.test/v1/challenge", { method: "POST" });
    const response = await worker.fetch(request, { ...env, CHALLENGE_SECRET: "", AI: { run: async () => null } } as Env);
    expect(response.status).toBe(503);
  });

  it("hands out challenges", async () => {
    const response = await call(new Request("https://plates.test/v1/challenge", { method: "POST" }));
    expect(((await response.json()) as { challenge: string }).challenge).toMatch(/^[A-Za-z0-9_-]{75}$/);
  });

  it("uses midnight UTC for the quota day", () => {
    expect(quotaDay(Date.UTC(2026, 8, 28, 23, 59, 59))).toBe("2026-09-28");
    expect(quotaDay(Date.UTC(2026, 8, 29))).toBe("2026-09-29");
  });
});

describe("attest", () => {
  it("rejects a stale challenge before reading the attestation", async () => {
    const response = await call(new Request("https://plates.test/v1/attest", {
      method: "POST",
      body: JSON.stringify({ keyId: base64Encode(new Uint8Array(32)), attestation: "AA==", challenge: "nope" }),
    }));
    expect(response.status).toBe(401);
  });
});

describe("writing", () => {
  it("refuses a request without a valid assertion", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/chat/completions", chat, { assertion: "AAAA" })).status).toBe(401);
    const stranger = await Phone.create(false);
    expect((await stranger.post("/v1/chat/completions", chat)).status).toBe(401);
    await runInDurableObject(stranger.stub(), (_, state) => {
      expect(state.storage.sql.exec("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE '_cf_%'").toArray()).toEqual([]);
    });
  });

  it("skips App Attest only on localhost when told to", async () => {
    const skipping = { ...env, SKIP_APP_ATTEST: "true", AI: { run: async () => ({ response: "" }) } } as Env;
    const post = (host: string) => worker.fetch(new Request(`http://${host}/v1/chat/completions`, { method: "POST", body: JSON.stringify(chat) }), skipping);
    expect((await post("localhost:8787")).status).toBe(200);
    expect((await post("plates.test")).status).toBe(401);
  });

  it("refuses a replayed assertion", async () => {
    const phone = await Phone.create();
    const body = new TextEncoder().encode(JSON.stringify(chat));
    const assertion = await phone.assertion(body);
    expect((await phone.post("/v1/chat/completions", chat, { assertion })).status).toBe(200);
    expect((await phone.post("/v1/chat/completions", chat, { assertion })).status).toBe(401);
  });

  it("returns Gemma's answer in the Chat Completions shape", async () => {
    const phone = await Phone.create();
    const run = vi.fn(async () => ({ choices: [{ message: { content: "Egg Fried Rice" } }] }));
    const response = await phone.post("/v1/chat/completions", { ...chat, temperature: 0.2 }, { ai: { run } });
    const body = (await response.json()) as { choices: { message: { content: string } }[] };
    expect(body.choices[0].message.content).toBe("Egg Fried Rice");
    expect(response.headers.get("X-Plates-Remaining")).toBe("2");
    expect(run).toHaveBeenCalledWith("@cf/google/gemma-4-26b-a4b-it", {
      messages: chat.messages, max_tokens: 1400, temperature: 0.2, stream: false, chat_template_kwargs: { enable_thinking: false },
    });
  });

  it("streams Gemma's text as chat completion chunks", async () => {
    const phone = await Phone.create();
    const run = async () => sse({ choices: [{ delta: { content: "Egg " } }] }, { choices: [{ delta: { content: "Fried Rice" } }] });
    const response = await phone.post("/v1/chat/completions", { ...chat, stream: true }, { ai: { run } });
    const text = await response.text();
    const contents = text.split("\n\n").filter((line) => line.startsWith("data: {"))
      .map((line) => JSON.parse(line.slice(6)).choices[0].delta.content ?? "").join("");
    expect(contents).toBe("Egg Fried Rice");
    expect(text.trim().endsWith("data: [DONE]")).toBe(true);
  });

  it("stops at the daily limit and gives back a failed write", async () => {
    const phone = await Phone.create();
    const broken = { run: async () => { throw new Error("gemma is down"); } };
    expect((await phone.post("/v1/chat/completions", chat, { ai: broken })).status).toBe(502);
    for (let i = 0; i < 3; i++) expect((await phone.post("/v1/chat/completions", chat)).status).toBe(200);
    const over = await phone.post("/v1/chat/completions", chat);
    expect(over.status).toBe(429);
    expect(over.headers.get("X-Plates-Remaining")).toBe("0");
  });

  it("counts ideas apart from recipes and keeps them short", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/ideate", { ...chat, max_tokens: 1400 })).status).toBe(400);
    for (let i = 1; i >= 0; i--) {
      const response = await phone.post("/v1/ideate", chat);
      expect(response.headers.get("X-Plates-Remaining")).toBe(String(i));
    }
    expect((await phone.post("/v1/ideate", chat)).status).toBe(429);
    expect((await phone.post("/v1/chat/completions", chat)).headers.get("X-Plates-Remaining")).toBe("2");
  });

  it("uses a limit set in the device's storage over the default", async () => {
    const phone = await Phone.create();
    await runInDurableObject(phone.stub(), (_, state) => {
      state.storage.sql.exec("INSERT INTO limits (kind, daily) VALUES ('write', 5), ('decide', 'lots')");
    });
    for (let i = 4; i >= 0; i--) {
      const response = await phone.post("/v1/chat/completions", chat);
      expect(response.headers.get("X-Plates-Remaining")).toBe(String(i));
    }
    expect((await phone.post("/v1/chat/completions", chat)).status).toBe(429);
    expect(await (await phone.post("/v1/limits", {})).json()).toEqual({
      write: { limit: 5, remaining: 0 }, ideate: { limit: 2, remaining: 2 }, decide: { limit: 2, remaining: 2 }, toppings: { limit: 2, remaining: 2 },
    });
  });

  it("rejects messages it will not pass on", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/chat/completions", { messages: [] })).status).toBe(400);
    expect((await phone.post("/v1/chat/completions", { ...chat, max_tokens: 5000 })).status).toBe(400);
    expect((await phone.post("/v1/chat/completions", { messages: [{ role: "tool", content: "x" }] })).status).toBe(400);
  });
});

describe("deciding", () => {
  it("asks Clef-flash and returns the pick with what is left today", async () => {
    const phone = await Phone.create();
    const run = clef("idea_2");
    const response = await phone.post("/v1/decide", ideas, { ai: { run } });
    expect(await response.json()).toEqual({ index: 1, confidence: 0.8, probabilities: [0.1, 0.9], remaining: 1 });
    const sent = run.mock.calls[0][1] as { model: string; questions: { pick: { criteria: object } }; state: { ideas: { [key: string]: object } } };
    expect(run.mock.calls[0][0]).toBe("@cf/cloudflare/clef-flash");
    expect(sent.model).toBe("clef-flash");
    expect(sent.questions.pick.criteria).toEqual({ idea_1: "Egg fried rice", idea_2: "Rice porridge" });
    expect(sent.state.ideas.idea_1).toEqual({ title: "Egg fried rice", summary: "One pan, 15 minutes" });
  });

  it("answers a retried set from memory without counting it again", async () => {
    const phone = await Phone.create();
    const run = clef("idea_1");
    await phone.post("/v1/decide", ideas, { ai: { run } });
    const again = await phone.post("/v1/decide", ideas, { ai: { run } });
    expect(((await again.json()) as { index: number; remaining: number })).toMatchObject({ index: 0, remaining: 1 });
    expect(run).toHaveBeenCalledTimes(1);
  });

  it("allows the limit each day, per device, and not a failed pick", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/decide", ideas, { ai: { run: clef("idea_1", true) } })).status).toBe(502);
    const ai = { run: clef("idea_1") };
    expect((await phone.post("/v1/decide", { ...ideas, requestId: "a" }, { ai })).status).toBe(200);
    expect((await phone.post("/v1/decide", { ...ideas, requestId: "b" }, { ai })).status).toBe(200);
    expect((await phone.post("/v1/decide", { ...ideas, requestId: "c" }, { ai })).status).toBe(429);
    const limits = await phone.post("/v1/limits", {});
    expect(await limits.json()).toMatchObject({ decide: { limit: 2, remaining: 0 } });
    const other = await Phone.create();
    expect((await other.post("/v1/decide", { ...ideas, requestId: "d" }, { ai })).status).toBe(200);
  });

  it("rejects a pick outside the ideas", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/decide", ideas, { ai: { run: clef("idea_9") } })).status).toBe(502);
  });

  it("rejects bad offsets and bad sets", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/decide", ideas, { offset: 2000 })).status).toBe(400);
    expect((await phone.post("/v1/decide", { ...ideas, ideas: [ideas.ideas[0]] })).status).toBe(400);
  });
});

describe("toppings", () => {
  const dish = {
    dish: "Spaghetti Carbonara",
    steps: [{ title: "Plate the carbonara", points: ["Finish with the last of the pecorino and more pepper."] }],
    ingredients: ["Pecorino", "Salt", "Pepper"],
  };

  function nouls(values: number[]) {
    return vi.fn(async (_model: string, _input: object) => ({
      model: "clef-flash",
      answers: Object.fromEntries(values.map((noul, index) => [`line_${index + 1}`, { type: "noul", noul }])),
      usage: { input_tokens: 1, output_tokens: 1 },
    }));
  }

  it("asks Clef-flash one question per line and returns the answers in order", async () => {
    const phone = await Phone.create();
    const run = nouls([0.96, 0.1, 0.93]);
    const response = await phone.post("/v1/toppings", dish, { ai: { run } });
    expect(await response.json()).toEqual({ visible: [0.96, 0.1, 0.93], remaining: 1 });
    expect(run.mock.calls[0][0]).toBe("@cf/cloudflare/clef-flash");
    const sent = run.mock.calls[0][1] as { state: object; questions: { [key: string]: object } };
    expect(sent.state).toEqual({ dish: "Spaghetti Carbonara", method: [{ step: "Plate the carbonara", points: dish.steps[0].points }] });
    expect(Object.keys(sent.questions)).toEqual(["line_1", "line_2", "line_3"]);
    expect(sent.questions.line_3).toMatchObject({ type: "noul", instructions: { ingredient: "Pepper" } });
  });

  it("gives back a call Clef-flash does not fully answer, and stops at the limit", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/toppings", dish, { ai: { run: nouls([0.9]) } })).status).toBe(502);
    const ai = { run: nouls([0.9, 0.1, 0.9]) };
    expect((await phone.post("/v1/toppings", dish, { ai })).status).toBe(200);
    expect((await phone.post("/v1/toppings", dish, { ai })).status).toBe(200);
    expect((await phone.post("/v1/toppings", dish, { ai })).status).toBe(429);
    expect(await (await phone.post("/v1/limits", {})).json()).toMatchObject({ toppings: { limit: 2, remaining: 0 } });
  });

  it("rejects a dish without lines or steps", async () => {
    const phone = await Phone.create();
    expect((await phone.post("/v1/toppings", { ...dish, ingredients: [] })).status).toBe(400);
    expect((await phone.post("/v1/toppings", { ...dish, steps: [] })).status).toBe(400);
  });
});

describe("quota integrity", () => {
  it("keeps exhausted quotas when the client changes UTC offsets", async () => {
    const phone = await Phone.create();
    for (let i = 0; i < 3; i++) expect((await phone.post("/v1/chat/completions", chat, { offset: -720 })).status).toBe(200);
    for (const offset of [-720, 840, -720, 0]) {
      expect((await phone.post("/v1/chat/completions", chat, { offset })).status).toBe(429);
      expect(await (await phone.post("/v1/limits", {}, { offset })).json()).toMatchObject({ write: { remaining: 0 } });
    }
  });

  it("does not let late refunds or answers reset the new day's usage", async () => {
    const phone = await Phone.create();
    const stub = phone.stub();
    await stub.reserve("decide", "2026-09-28", 2, "old");
    await stub.reserve("decide", "2026-09-29", 2, "new");
    await stub.release("decide", "2026-09-28");
    await stub.remember("decide", "2026-09-28", "old", { index: 0, confidence: 1, probabilities: [1, 0] });
    expect(await stub.allowance("decide", "2026-09-29", 2)).toEqual({ limit: 2, remaining: 1 });
    await stub.release("decide", "2026-09-29");
    expect(await stub.allowance("decide", "2026-09-29", 2)).toEqual({ limit: 2, remaining: 2 });
  });
});
