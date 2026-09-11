import { phraseAnswerHandler } from "../phraseAnswer";
import * as qwen from "../qwen";

jest.mock("../qwen");

const SAMPLE_PLAN = {
  found: true,
  origin: "University Town",
  destination: "Saddar",
  legs: [
    {
      route_id: "ER-01",
      route_label: "BRT Xpress Route 01",
      service_type: "express",
      board_station: "University Town",
      alight_station: "Saddar",
      ride_time_min: 22.5,
      wait_time_min: 3.0,
    },
  ],
  transfers: [],
  total_time_min: 25.5,
  fare: {
    total_pkr: 45,
    basis: "distance_band",
    is_estimate: true,
    note: "About 12.4 km of travel falls in fare band 3, Rs. 45.",
  },
  warnings: [],
};

describe("phraseAnswerHandler", () => {
  it("passes the plan to Qwen and returns its reply text", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      "Take the ER-01 from University Town to Saddar, about 26 minutes, Rs. 45."
    );

    const result = await phraseAnswerHandler({ plan: SAMPLE_PLAN });

    expect(result).toEqual({
      reply: "Take the ER-01 from University Town to Saddar, about 26 minutes, Rs. 45.",
    });
    expect(qwen.callQwen).toHaveBeenCalledWith(
      expect.any(String),
      JSON.stringify(SAMPLE_PLAN)
    );
  });

  it("passes through a not-found plan's message without inventing a route", async () => {
    const notFound = { found: false, message: "Origin and destination are the same station." };
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      "Looks like your origin and destination are the same stop."
    );

    const result = await phraseAnswerHandler({ plan: notFound });

    expect(result.reply).toContain("same stop");
  });
});
