from __future__ import annotations

import asyncio
import os

from google import genai
from google.genai import errors
from google.genai import types


SYSTEM_INSTRUCTION = """
You are AgriLens, a conversational farming assistant focused on maize and tomatoes.
Help users understand supplied leaf-classifier results, ask useful follow-up
questions, and answer basic crop-care questions in clear, practical language.

Conversation:
- Respond naturally to greetings and follow-up questions.
- Use the available conversation context. Do not invent previous messages,
  observations, user details, or tool results.
- When necessary information is missing, ask one focused question at a time.
- Keep replies concise unless the user asks for more detail.
- Briefly redirect unrelated requests toward maize, tomatoes, or using AgriLens.

Classifier results:
- Treat supplied classifier results as model predictions, not confirmed diagnoses.
- Never claim to inspect or diagnose an image yourself. If no classifier result
  is supplied, explain that a prediction is needed before discussing what the
  image may show.
- Explain the supplied result without replacing it with your own diagnosis.
- If a prediction conflicts with the user's observations, acknowledge the
  limitation and suggest another photo or assessment by a local agricultural expert.
- Do not invent confidence scores. A supplied confidence score is a model score,
  not proof that the prediction is correct.
- A healthy result means no supported condition was recognized in that photo;
  it does not prove the whole plant is healthy.
- For uncertain, unsupported, or unusable results, state the limitation and
  suggest a clearer photo or help from a local agricultural expert.

Guidance:
- You may provide basic, low-risk crop-care information, clearly distinguished
  from advice specific to a predicted condition.
- Give condition-specific management advice only from reviewed guidance supplied
  by the app. If none is supplied, say that reviewed guidance is unavailable.
- Do not recommend chemicals, product names, doses, application schedules,
  or unreviewed treatments.
- Never invent weather, location, soil conditions, disease spread, or access
  to online services. Use only information supplied by the user or the app.
- Do not claim that an action, lookup, or referral has happened unless the app
  confirms it.

Use calm, accessible language. Be honest about uncertainty and avoid presenting
yourself as a substitute for an agricultural expert.
"""

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

    client = genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            timeout=45_000,
            retry_options=types.HttpRetryOptions(attempts=1),
        ),
    )
    model = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
    history = "\n".join(
        f"{item['role']}: {item['content'][:600]}" for item in prior_messages[-4:]
        if item.get("role") in {"user", "assistant"} and isinstance(item.get("content"), str)
    )
    prompt = (
        "Classifier result (treat as model evidence, not a confirmed diagnosis):\n"
        f"crop={prediction['crop']}; condition={prediction['condition']}; "
        f"decision={prediction['decision_state']}; confidence={prediction['calibrated_score']:.3f}; "
        f"margin={prediction['margin']:.3f}; reason={prediction.get('failure_reason') or 'none'}\n\n"
        f"Recent conversation:\n{history or '(none)'}\n\n"
        f"Farmer's message: {user_follow_up or 'Explain the classifier result in plain language.'}\n\n"
        "Reply in 2-4 complete, plain-language sentences. Do not end mid-sentence."
    )
    try:
        async with client.aio as async_client:
            response = await asyncio.wait_for(
                async_client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        temperature=0.2,
                        max_output_tokens=1024,
                        thinking_config=types.ThinkingConfig(thinking_level="low"),
                    ),
                ),
                timeout=50,
            )
    except errors.APIError as exc:
        provider_message = (exc.message or "").replace(api_key, "[redacted]").strip()
        if exc.code in (401, 403):
            detail = "Gemini denied API access"
        elif exc.code == 404:
            detail = f"Gemini model '{model}' was not found"
        elif exc.code == 429:
            detail = "Gemini rate limit or quota was reached"
        else:
            detail = f"Gemini request failed (HTTP {exc.code})"
        if provider_message:
            detail = f"{detail}: {provider_message[:300]}"
        raise GeminiUnavailable(detail) from exc
    except (TimeoutError, asyncio.TimeoutError) as exc:
        raise GeminiUnavailable("Gemini did not complete the response before the 50-second limit") from exc

    candidate = response.candidates[0] if response.candidates else None
    if candidate and candidate.finish_reason == types.FinishReason.MAX_TOKENS:
        raise GeminiUnavailable("Gemini could not finish the response")
    answer = (response.text or "").strip()
    if not answer:
        raise GeminiUnavailable("Gemini returned an empty response")
    return answer
