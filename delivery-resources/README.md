# Delivery Resources

Presenter and train-the-trainer materials for **BRK240 — Building context-aware agents with
Microsoft IQ platform** (FY27 Caldova, Chapter 01 "Ground").

## Delivery checklist

- Review the session [README](../README.md) and attendee [instructions](../instructions/README.md)
- Review the [demo flows](demos/README.md) (per-demo run of show + prompts)
- Open the deck (Caldova FY27 storyline)
- Validate the environment: agent deployed + hired, all four IQ connections healthy, Caldova
  corpus seeded (Foundry IQ KB + Fabric IQ)
- Warm the Fabric Data Agent with one query before going live

## Core materials

| Item | Link | Notes |
|---|---|---|
| Delivery deck | _add link_ | Caldova FY27 storyline (Chapter 01 "Ground") |
| Session recording | _add link_ |  |
| Demo flows | [demos/README.md](demos/README.md) | Three per-demo walkthroughs + prompts |
| Setup / deploy | [../docs/setup.md](../docs/setup.md) | Provision, seed, register |
| Attendee instructions | [../instructions/README.md](../instructions/README.md) | Start here for the guided path |

## Run of show (~20 min demo block)

| Time | Demo | IQ | What you show |
|:---|:---|:---|:---|
| 0:00 | Frame | — | "No shared context → wrong decisions." Introduce the four IQs + Caldova. |
| 2:00 | [Demo 1](demos/demo-01-grounding-web-foundry-iq.md) | **Web IQ + Foundry IQ** | Chat with the deployed agent: live web context + the Caldova knowledge base (sources + index). |
| 8:00 | [Demo 2](demos/demo-02-fabric-iq.md) | **Fabric IQ** | Fabric workspace, ontology, Data Agent + instructions, and the agent's code wiring. |
| 13:00 | [Demo 3](demos/demo-03-all-iqs-teams-governance.md) | **All four** | Work IQ in Foundry, the full flow in Teams, the email proof in Outlook, and Agent 365 governance. |
| 19:00 | Close | — | "Amplify your intelligence — build one agent, then the fleet on the same IQ." |

## Key messages

1. **Context is the differentiator** — the four IQs give agents trusted enterprise grounding.
2. **One backbone, many agents** — build one agent grounded in Microsoft IQ, then the next one
   faster on the *same* IQ (no new connectors or RAG).
3. **Enterprise-ready** — permission-aware, traceable, centrally governed via Agent 365.

## Support

Content owners / contacts: **Ayça Baş** (https://github.com/aycabas) and **Pamela Fox** (https://github.com/pamelafox)
