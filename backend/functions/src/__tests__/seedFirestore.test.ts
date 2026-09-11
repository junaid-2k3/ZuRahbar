import { buildBatches } from "../../scripts/seedFirestore";

describe("buildBatches", () => {
  it("flattens every collection into (collection, docId, data) triples", () => {
    const seed = {
      routes: { "ER-01": { route_id: "ER-01" } },
      stations: { chamkani: { station_id: "chamkani" } },
      fares: { current: { currency: "PKR" } },
      service_hours: { current: { opens: "06:00" } },
    };

    const batches = buildBatches(seed);

    expect(batches).toEqual(
      expect.arrayContaining([
        { collection: "routes", docId: "ER-01", data: { route_id: "ER-01" } },
        { collection: "stations", docId: "chamkani", data: { station_id: "chamkani" } },
        { collection: "fares", docId: "current", data: { currency: "PKR" } },
        { collection: "service_hours", docId: "current", data: { opens: "06:00" } },
      ])
    );
    expect(batches).toHaveLength(4);
  });
});
