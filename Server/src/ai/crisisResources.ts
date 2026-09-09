export interface CrisisResource {
  name: string;
  phone: string;
  telHref: string; // tel: link for one-tap calling on iOS (PRD Section 8)
  description: string;
}

export const CRISIS_RESOURCES: CrisisResource[] = [
  {
    name: "National Problem Gambling Helpline",
    phone: "1-800-522-4700",
    telHref: "tel:+18005224700",
    description: "Confidential support for gambling-related distress. Text and chat also available.",
  },
  {
    name: "988 Suicide & Crisis Lifeline",
    phone: "988",
    telHref: "tel:988",
    description: "For thoughts of suicide or self-harm.",
  },
];

/**
 * The message shown alongside crisis resources. Calm, non-clinical, never
 * attempts to talk the user out of the crisis (PRD Section 8) — the
 * agent's only job in this moment is to surface real help clearly.
 */
export const CRISIS_RESPONSE_MESSAGE =
  "It sounds like you're going through something really hard right now. " +
  "I'm not able to give you the kind of support you deserve in this moment, " +
  "but real help is available right now — please reach out to one of the resources below.";
