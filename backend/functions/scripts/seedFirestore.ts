//
// Manual run, once per dataset refresh: node lib-scripts/seedFirestore.js
// Requires GOOGLE_APPLICATION_CREDENTIALS pointed at a service account key
// for your Firebase project (see plan Step 5 for setup).
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";

export interface FirestoreSeed {
  routes: Record<string, object>;
  stations: Record<string, object>;
  fares: Record<string, object>;
  service_hours: Record<string, object>;
}

export interface SeedBatch {
  collection: string;
  docId: string;
  data: object;
}

export function buildBatches(seed: FirestoreSeed): SeedBatch[] {
  const batches: SeedBatch[] = [];
  for (const [collection, docs] of Object.entries(seed)) {
    for (const [docId, data] of Object.entries(docs)) {
      batches.push({ collection, docId, data: data as object });
    }
  }
  return batches;
}

async function main() {
  const seedPath = path.resolve(__dirname, "../../../data/export/firestore_seed.json");
  const seed = JSON.parse(fs.readFileSync(seedPath, "utf-8")) as FirestoreSeed;
  const batches = buildBatches(seed);

  admin.initializeApp();
  const db = admin.firestore();
  const writer = db.bulkWriter();
  for (const { collection, docId, data } of batches) {
    writer.set(db.collection(collection).doc(docId), data);
  }
  await writer.close();
  console.log(`Seeded ${batches.length} documents across ${Object.keys(seed).length} collections.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
