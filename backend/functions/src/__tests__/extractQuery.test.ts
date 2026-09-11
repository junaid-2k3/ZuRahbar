import { extractQueryHandler } from "../extractQuery";
import * as qwen from "../qwen";

jest.mock("../qwen");

describe("extractQueryHandler", () => {
  it("parses Qwen's JSON reply into origin/destination/intent", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      JSON.stringify({ origin: "University Town", destination: "Saddar", intent: "route" })
    );

    const result = await extractQueryHandler({ text: "how do I get from uni town to saddar" });

    expect(result).toEqual({
      origin: "University Town",
      destination: "Saddar",
      intent: "route",
    });
  });

  it("returns nulls when Qwen can't find one side of the trip", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      JSON.stringify({ origin: null, destination: "Hayatabad", intent: "route" })
    );

    const result = await extractQueryHandler({ text: "how do I get to hayatabad" });

    expect(result.origin).toBeNull();
    expect(result.destination).toBe("Hayatabad");
  });

  it("throws if Qwen's reply is not valid JSON", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue("not json");

    await expect(extractQueryHandler({ text: "anything" })).rejects.toThrow(
      "Qwen returned an unparseable extraction response"
    );
  });
});
