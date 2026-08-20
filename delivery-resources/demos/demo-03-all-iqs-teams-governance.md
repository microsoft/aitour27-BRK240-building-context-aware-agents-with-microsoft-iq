# Demo 3 — All four IQs as a governed teammate

> Recording: _add link_ · Duration target: ~6–7 min

**Goal.** Bring it together: the **same agent**, grounded across all four IQs, runs
as a **governed Agent 365 autopilot** in Microsoft Teams — reading its mailbox,
ranking suppliers, grounding in policy and contracts, checking the web, and replying
to a real escalation — then show the **governance** that makes it safe: it reports to
its owner, needs its own licenses, and has a human in the loop.

**Why it matters.** This is the payoff: not four tools, but one context-aware teammate
that acts end to end under enterprise governance.

## Setup

> New environment? Do the [setup](../../docs/setup.md) first (prerequisites + deploy + seed).

- The autopilot is **hired** in Teams (1:1 chat reachable).
- A seeded escalation email from **Maria Garcia** is **unread** in the *agent's own
  mailbox* (not the presenter's mailbox).
- Warm up Fabric IQ (one OTIF question) before starting.
- Microsoft 365 admin center open on the agent's template / instance pages.

> **Teams version note.** A Teams 1:1 conversation pins to the agent version active
> when the session started. After any redeploy, retire the old version (force) so the
> next message rolls to `@latest` before you record.

## Instructions

### Part A — Work IQ in the Foundry Toolkit (prove it reads real mail)

1. In the **VS Code Foundry Toolkit**, chat with the agent and ask:

   > Any urgent supply escalations in your mailbox?

2. Show it finds **Maria Garcia's** escalation — proving Work IQ reads the agent's
   real mailbox, not a canned response.

   > **Verify before recording.** Work IQ (like Fabric) needs a user-delegated OBO
   > token. It flows reliably on the **Teams** activity path (Part B); whether it also
   > resolves via the Toolkit `/responses` endpoint depends on the signed-in context —
   > test it first. If it doesn't answer in the Toolkit, do this Work IQ beat in **Teams**
   > (Part B step 1) instead.

### Part B — the full flow in Teams

3. Switch to **Microsoft Teams**. Before chatting, **hover the agent** and show it's
   an **autopilot that reports to you** — not an installed app. (Governance teaser.)
4. Run the flow, one message at a time:

   | # | Ask | IQ |
   |---|---|---|
   | 1 | Any urgent supply escalations in your mailbox? | Work IQ (read) |
   | 2 | Is a major cold-chain excursion eligible for replacement and credit? | Foundry IQ (policy) |
   | 3 | Rank suppliers by OTIF and flag any with open regulatory actions. | Fabric IQ |
   | 4 | Why was Summit Dose awarded CALD-201? | Foundry IQ (procurement) |
   | 5 | What did BluePeak's GMP inspection find? | Foundry IQ (quality) |
   | 6 | Which active substances have only one approved manufacturer? | Fabric IQ (ontology) |
   | 7 | Any weather or carrier disruptions this week that could affect cold-chain shipments? | Web IQ |
   | 8 | Reply to Maria's escalation: confirm replacement + credit per policy, note the supplier's standing and the disruption, and list next steps. | Work IQ (reply) |

5. On step 8, the agent composes and **sends** the reply through Work IQ.

### Part C — the email proof (Outlook)

6. Open the **agent's Outlook** and show the reply actually landed in the thread —
   confirming the agent didn't just claim to send; it acted.

### Part D — governance (Microsoft 365 admin center)

7. In the **admin center**, open the **agent template** and show the **Licenses**
   section — call out the **Frontier** license requirement.
8. Open the **Instances** tab, click **your instance**, and show it needs licenses
   like a person does — **E5** and the other required licenses.
9. Show that **you are the owner and manager** of the agent — the human in the loop.
   "It runs autonomously, but it reports to me, it's licensed like a teammate, and I
   own it."

## Questions used

See the table in Part B. Ask one at a time, single-intent. Keep Maria's email unread
until step 1. For step 6 (relationships), don't combine two conditions in one ask.

## Expected result

- All four IQs answer through one Teams agent.
- The agent sends a real reply visible in Outlook.
- The admin center shows the autopilot's licenses, ownership, and human-in-the-loop
  governance.

## Talk track

> "One agent, four kinds of context, acting end to end — reading the escalation,
> ranking suppliers on real data, grounding in policy and contracts, checking the web,
> and replying. And it's governed: it reports to me, it's licensed like a teammate, and
> I'm the owner and the human in the loop. That's a context-aware agent you can
> actually put to work."

## Transcript

_After recording, paste the final timed transcript here (also lives in the deck speaker notes)._
