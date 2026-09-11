import { callQwen } from "../qwen";

function jsonResponse(body: unknown, init?: { ok?: boolean; status?: number }): Response {
  return {
    ok: init?.ok ?? true,
    status: init?.status ?? 200,
    json: async () => body,
    text: async () => JSON.stringify(body),
  } as unknown as Response;
}

describe("callQwen", () => {
  const originalFetch = global.fetch;
  const originalApiKey = process.env.DASHSCOPE_API_KEY;

  beforeEach(() => {
    process.env.DASHSCOPE_API_KEY = "test-key";
  });

  afterEach(() => {
    global.fetch = originalFetch;
    if (originalApiKey === undefined) {
      delete process.env.DASHSCOPE_API_KEY;
    } else {
      process.env.DASHSCOPE_API_KEY = originalApiKey;
    }
    jest.restoreAllMocks();
  });

  it("returns the completion content on success", async () => {
    jest.spyOn(global, "fetch").mockResolvedValue(
      jsonResponse({ choices: [{ message: { content: "hello rider" } }] })
    );

    const result = await callQwen("system prompt", "user message");

    expect(result).toBe("hello rider");
  });

  it("throws an error including the status when the response is not ok", async () => {
    jest.spyOn(global, "fetch").mockResolvedValue(
      jsonResponse(
        { error: "boom" },
        { ok: false, status: 503 }
      )
    );

    await expect(callQwen("system prompt", "user message")).rejects.toThrow("503");
  });

  it("throws a clear error when the response body is malformed", async () => {
    jest.spyOn(global, "fetch").mockResolvedValue(jsonResponse({ choices: [] }));

    await expect(callQwen("system prompt", "user message")).rejects.toThrow(
      "Qwen returned no completion content"
    );
  });

  it("throws if DASHSCOPE_API_KEY is not set", async () => {
    delete process.env.DASHSCOPE_API_KEY;

    await expect(callQwen("system prompt", "user message")).rejects.toThrow(
      "DASHSCOPE_API_KEY is not set"
    );
  });
});
