import { callQwen } from "./qwen";

const SYSTEM_PROMPT = `You extract trip intent from a Zu Transport (Peshawar BRT) rider's
message. Reply with ONLY a JSON object: {"origin": string|null, "destination": string|null,
"intent": "route"|"fare"|"other"}. Use null for a side of the trip the rider didn't mention.
Do not invent a location the rider didn't say.`;

export interface ExtractQueryRequest {
  text: string;
}

export interface ExtractQueryResult {
  origin: string | null;
  destination: string | null;
  intent: string;
}

export async function extractQueryHandler(
  request: ExtractQueryRequest
): Promise<ExtractQueryResult> {
  const reply = await callQwen(SYSTEM_PROMPT, request.text);
  try {
    return JSON.parse(reply) as ExtractQueryResult;
  } catch {
    throw new Error("Qwen returned an unparseable extraction response");
  }
}
