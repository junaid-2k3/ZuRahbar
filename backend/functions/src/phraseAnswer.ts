import { callQwen } from "./qwen";

const SYSTEM_PROMPT = `You are Rehbar, a friendly assistant for Zu Transport (Peshawar BRT)
riders. You are given a JSON journey plan already computed by deterministic code — never
recompute or contradict its route, fare, or timing numbers. If "found" is false, explain
the "message" field plainly. Keep the reply short and conversational. If "fare".note
mentions a caveat (e.g. an express flat-fare exception), mention it briefly rather than
asserting a fare with false certainty.`;

export interface JourneyPlanPayload {
  found: boolean;
  message?: string;
  [key: string]: unknown;
}

export interface PhraseAnswerRequest {
  plan: JourneyPlanPayload;
}

export interface PhraseAnswerResult {
  reply: string;
}

export async function phraseAnswerHandler(
  request: PhraseAnswerRequest
): Promise<PhraseAnswerResult> {
  const reply = await callQwen(SYSTEM_PROMPT, JSON.stringify(request.plan));
  return { reply };
}
