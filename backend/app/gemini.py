from __future__ import annotations

import os

from google import genai
from google.genai import types


SYSTEM_INSTRUCTION = """You are an assistant in AgriLens, a maize and tomato leaf decision-support app.
Explain only the supplied classifier result. Do not diagnose an image, override the classifier,
claim field certainty, or prescribe chemicals, doses, or unreviewed treatments. If the result is
uncertain, say so and suggest a clearer photo or local agricultural expert. A healthy result means
no supported condition was recognized in this photo; it does not prove the plant is healthy.
Keep answers concise and do not invent reviewed guidance that was not supplied."""


class GeminiUnavailable(RuntimeError):
    pass


async def generate_answer(
    *,
    prediction: dict,
    prior_messages: list[dict[str, str]],
    user_follow_up: str | None,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        raise GeminiUnavailable("Gemini is not configured on the server")

    client = genai.Client(api_key=api_key)
    model = os.getenv("GEMINI_MODEL", "gemini-3.8-flash")
    history = "\n".join(
        f"{item['role']}: {item['content'][:1200]}" for item in prior_messages[-8:]
        if item.get("role") in {"user", "assistant"} and isinstance(item.get("content"), str)
    )
    prompt = (
        "Classifier result (treat as model evidence, not a confirmed diagnosis):\n"
        f"crop={prediction['crop']}; condition={prediction['condition']}; "
        f"decision={prediction['decision_state']}; confidence={prediction['calibrated_score']:.3f}; "
        f"margin={prediction['margin']:.3f}; reason={prediction.get('failure_reason') or 'none'}\n\n"
        f"Recent conversation:\n{history or '(none)'}\n\n"
        f"Farmer's message: {user_follow_up or 'Explain the classifier result in plain language.'}"
    )
    response = await client.aio.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION,
            temperature=0.2,
            max_output_tokens=256,
        ),
    )
    answer = (response.text or "").strip()
    if not answer:
        raise GeminiUnavailable("Gemini returned an empty response")
    return answer
