import { onRequest } from "firebase-functions/v2/https";
import { extractQueryHandler, ExtractQueryRequest } from "./extractQuery";
import { phraseAnswerHandler, PhraseAnswerRequest } from "./phraseAnswer";

export const extractQuery = onRequest(
  { secrets: ["DASHSCOPE_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const result = await extractQueryHandler(req.body as ExtractQueryRequest);
      res.status(200).json(result);
    } catch (error) {
      res.status(502).json({ error: (error as Error).message });
    }
  }
);

export const phraseAnswer = onRequest(
  { secrets: ["DASHSCOPE_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const result = await phraseAnswerHandler(req.body as PhraseAnswerRequest);
      res.status(200).json(result);
    } catch (error) {
      res.status(502).json({ error: (error as Error).message });
    }
  }
);
