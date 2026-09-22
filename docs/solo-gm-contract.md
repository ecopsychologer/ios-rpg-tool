# Solo GM Contract

This project keeps the RPG engine, persistent world state, and narrator as separate responsibilities.

## Boundaries

- The player controls player choices, intent, next actions, and character feelings.
- The engine controls rules, randomness, canonical facts, rolls, DCs, resources, time, active location, and consequences.
- The narrator renders already-adjudicated facts into playable prose. It does not roll dice, move the party, create durable state, or decide player actions.
- New narrator-created content is only a proposal until the engine classifies and accepts it.

## Turn Pipeline

1. Parse player text into character intent and world assumptions.
2. Resolve world assumptions through GM authority. Unestablished weather is accepted, softened, or rejected in the same turn.
3. Build a structured `NarratorTurnDraft`; never accept model prose as canonical state.
4. Validate proposal source, visibility, durability, approval, bindings, discovery state, and player authority.
5. Convert approved changes into typed `CampaignEvent` records and apply them through `CampaignReducer`.
6. Render player-visible prose from canonical state, approved events, player-visible facts, and locked stakes.
7. Validate direct-answer ordering, solo language, scene continuity, agency, and the open decision prompt.
8. Retry rendering at most once. On another validation failure, use a deterministic engine-authored fallback.

Summaries are outside this mutation pipeline. `SceneSummaryDraft` is read-only and may reference existing canon only. Unknown summary references log `summary_hallucination` and trigger a deterministic event-based summary.

## Narration Rules

- Never narrate player agency with phrases like "you decide", "the party decides", "the player decides", or "you feel compelled".
- Never use success to add a secret penalty or hidden enemy unless that consequence was in the declared stakes.
- Answer direct player questions directly before adding narration or asking for a check.
- GM/meta requests summarize known state only. They must not introduce new fiction or mutate world state.
- Keep every response concrete and playable: name the clue, risk, sound, object, exit, cost, or changed condition.
- End playable turns with "What do you do?" or a focused clarifying question.

## State Tiers

- Narration only: mood, color, sensory texture, and temporary phrasing.
- Scene fact: useful for the current scene but not durable unless reused or confirmed.
- Durable world fact: accepted NPCs, locations, objects, lore, threats, and clues.
- Hidden GM fact: clocks, threats, ambushes, or secrets not shown to the player yet.
- Mechanical state: HP, resources, active location, time, rests, conditions, and rolls.
- Canon proposal: uncertain facts awaiting engine or player confirmation.

All canonical mutations are event-reduced. Event records persist source, visibility, durability, approval, bindings, and encoded payloads. Duplicate event IDs are idempotent, rejected events are no-ops, and legacy logs without event payloads remain loadable.

Generic unknowns are not entities. Phrases such as "Unknown Character" or "unseen adversary" may become an engine-owned clue or clock, but never an NPC. Companions, character history, motives, feelings, and irreversible commitments require explicit player confirmation.

## Stakes

Checks lock success, partial, failure, critical success, critical failure, allowed mutations, and forbidden mutations before the roll. Narration may only render the resolved envelope.

- A natural 20 gives the best plausible result within the declared situation; it does not make impossible actions unlimited.
- A lore partial gives a broad association only. It cannot create a map, chamber, quest, treasure, NPC, or location.
- Success may reveal a prepared hidden target. It cannot generate a target after the roll.
- Consequences cannot add secret penalties that were absent from the declared stakes.

## Questions And Prompts

Question and meta intents run deterministic state queries before narration. `directAnswer` is authoritative and must render first as `yes`, `no`, `unknown`, `check_required`, or `not_applicable`.

- Hidden-door questions consult known features and edges before requesting a check.
- Meta summaries read player-known state and assert a zero state diff.
- Solo narration uses the character name or "you" unless an ally is actually present.
- Outdoor scenes cannot mention building details such as windows without an established building.
- Open Table is the default prompt mode. Guided mode may offer at most three suggestions plus "something else."

## Procedures

Travel, rest, and search use persisted request and resolution state machines. Procedure state is encoded on the campaign and changed through procedure events.

- Travel resolves as a roll, no-roll transition, blocked movement, route choice, or explicit time/resource update. Progress, time, weather, exposure, delay, and encounter risk are separate values.
- Rest asks only for missing kind, shelter, watch, and fire details. Resolution records time, recovery, supplies, exposure, watch risk, and interruption.
- Search distinguishes moving observation from close investigation. Skill, DC, stakes, and prepared hidden targets lock before resolution.
- Spatial state uses locations, nodes, features, and edges. Discovery makes an edge available; only explicit movement changes the active node. A discovered trapdoor remains unopened until the player enters it.
- Creative solutions draw two or three seeded keywords, take a straight d20, select a bounded engine effect, then request narrator flavor. Creative effects cannot create an NPC or location.

## Test Expectations

- Context prompts must keep a hard output buffer and compact older state.
- Road scenes must not become dungeons without a player travel choice or accepted engine transition.
- Unestablished sidekicks, companions, or hidden adversaries must not become NPCs automatically.
- d20 rolls must stay in 1...20 and d100 rolls in 1...100; logs must label die types correctly.
- Rest, lore, question, and meta intents need specialized behavior instead of generic scene narration.
- Quick smoke covers summary isolation, weather authority, travel resolution, direct questions, and hidden-feature search.
- Thorough testing covers every authority boundary, solo-language validation, discovery versus entry, lore partials, rest interruption state, creative tactics, invalid narrator packets, and fallback behavior.
- Handoff logs include intent/assumptions, stakes, proposal approvals and rejections, campaign events, procedure state, retries, fallbacks, structural failures, and state snapshots.

The structural golden fixture is `Packages/RPGEngine/Tests/Fixtures/gm_authority_golden.json`. Tests must not depend on exact model wording.
