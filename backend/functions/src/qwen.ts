export async function callQwen(systemPrompt: string, userMessage: string): Promise<string> {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  // Alibaba Model Studio's international endpoint (an `sk-…` key). Kept in
  // step with app/lib/main.dart, which moved off ModelScope because that host
  // is unreachable from Peshawar.
  const baseUrl =
    process.env.QWEN_API_BASE_URL ?? "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
  const model = process.env.QWEN_MODEL ?? "qwen-plus";

  if (!apiKey) {
    throw new Error("DASHSCOPE_API_KEY is not set");
  }

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userMessage },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Qwen request failed: ${response.status} ${await response.text()}`);
  }

  const data = (await response.json()) as {
    choices?: { message?: { content?: unknown } }[];
  };
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("Qwen returned no completion content");
  }
  return content;
}
