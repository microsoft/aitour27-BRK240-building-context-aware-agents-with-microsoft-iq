# Delivery Resources

Presenter and train-the-trainer materials for **BRK240 — Building context-aware agents with
Microsoft IQ platform** (FY27 Caldova, Chapter 01 "Ground").

## Delivery checklist

- Review the session [README](../README.md) and attendee [instructions](../instructions/README.md)
- Review the [demo flows](demos/README.md) (five per-demo run of show + prompts)
- Open the deck (Caldova FY27 storyline)
- Validate the environment: agent deployed + hired, all four IQ connections healthy, Caldova
  corpus seeded (Foundry IQ KB + Fabric IQ)
- Warm the Fabric Data Agent with one query before going live

## Core materials

| Item | Link | Notes |
|---|---|---|
| Delivery deck | _add link_ | Caldova FY27 storyline (Chapter 01 "Ground") |
| Full session recording | _add link_ | The full session presentation |
| Demo flows | [demos/README.md](demos/README.md) | Five per-demo walkthroughs + prompts |
| Setup / deploy | [../docs/setup.md](../docs/setup.md) | Provision, seed, register |
| Attendee instructions | [../instructions/README.md](../instructions/README.md) | Start here for the guided path |

## Demo recordings

One clip per demo, in two versions: a **clean capture** with no audio (for you to
voice over live) and a **voice-over** version with narration. The written run of show
and prompts for each demo are in the linked instructions.

| # | Demo | Instructions | Clip — no audio | Clip — voice-over |
|---|---|---|---|---|
| 1 | Web IQ | [web-iq.md](demos/web-iq.md) | _add video_ | _add video_ |
| 2 | Foundry IQ | [foundry-iq.md](demos/foundry-iq.md) | _add video_ | _add video_ |
| 3 | Fabric IQ | [fabric-iq.md](demos/fabric-iq.md) | _add video_ | _add video_ |
| 4 | Work IQ | [work-iq.md](demos/work-iq.md) | _add video_ | _add video_ |
| 5 | All four IQs + the autopilot | [all-4-iqs-autopilot.md](demos/all-4-iqs-autopilot.md) | _add video_ | _add video_ |

> To add a clip, edit this file in the GitHub web editor and **drag the video into a
> cell** (or paste it). GitHub uploads it to `user-attachments` and renders an inline
> player — replace the `_add video_` placeholder. Keep each file under GitHub's upload
> limit (~100 MB); host anything larger externally and link it instead.

## Run of show (~20 min demo block)

| Time | Demo | IQ | What you show |
|:---|:---|:---|:---|
| 0:00 | Frame | — | "No shared context → wrong decisions." Introduce the four IQs + Caldova. |
| 2:00 | [Web IQ](demos/web-iq.md) | **Web IQ** | Live-web grounding in the Playground; the Web IQ call in Traces; the code. |
| 5:00 | [Foundry IQ](demos/foundry-iq.md) | **Foundry IQ** | Cited policy answer; Foundry IQ in Traces; the knowledge base; the code. |
| 8:00 | [Fabric IQ](demos/fabric-iq.md) | **Fabric IQ** | Numbers *and* the medicinal-product ontology via the Data Agent; Traces; the code. |
| 12:00 | [Work IQ](demos/work-iq.md) | **Work IQ** | Reads your real mailbox on-behalf-of you; Work IQ in Traces; Outlook; the code. |
| 15:00 | [All four IQs + the autopilot](demos/all-4-iqs-autopilot.md) | **All four** | The governed autopilot in Teams — all four IQs, replies from its mailbox, admin governance. |
| 19:00 | Close | — | "Amplify your intelligence — build one agent, then the fleet on the same IQ." |

## Key messages

1. **Context is the differentiator** — the four IQs give agents trusted enterprise grounding.
2. **One backbone, many agents** — build one agent grounded in Microsoft IQ, then the next one
   faster on the *same* IQ (no new connectors or RAG).
3. **Enterprise-ready** — permission-aware, traceable, centrally governed via Agent 365.

## Support

Content owners / contacts: **Ayça Baş** (https://github.com/aycabas) and **Pamela Fox** (https://github.com/pamelafox)
