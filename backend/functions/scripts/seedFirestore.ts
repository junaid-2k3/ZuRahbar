//
// Manual run, once per dataset refresh: node lib/scripts/seedFirestore.js
// (build first with `npm run build`; or run directly against the source with
// `npx ts-node scripts/seedFirestore.ts` from backend/functions).
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

// __dirname is backend/functions/scripts when run via ts-node from source,
// or backend/functions/lib/scripts when run as the compiled JS output — the
// compiled path sits one directory deeper (an extra "lib" segment), so the
// two cases need a different number of "../" hops to reach backend/functions.
// Resolve to backend/functions first, then step up to the repo root, so the
// result is correct regardless of which form is running.
function resolveSeedPath(dirname: string): string {
  const isCompiled = dirname.endsWith(path.join("lib", "scripts"));
  const functionsRoot = isCompiled ? path.resolve(dirname, "../..") : path.resolve(dirname, "..");
  return path.resolve(functionsRoot, "../../data/export/firestore_seed.json");
}

async function main() {
  const seedPath = resolveSeedPath(__dirname);
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
