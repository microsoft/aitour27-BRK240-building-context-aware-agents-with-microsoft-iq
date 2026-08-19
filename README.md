<a name="start-building"></a>

<p align="center">
<img src="img/banner-ai-tour-27.png" alt="Microsoft AI Tour 2027" width="100%"/>
</p>

# [Microsoft AI Tour 2027](https://aitour.microsoft.com)

## 🔥 BRK240: Building context-aware agents with Microsoft IQ

### Session Description

With no shared context, agents make wrong decisions. This session shows how the **Microsoft IQ platform** — **Foundry IQ**, **Fabric IQ**, **Work IQ**, and **Web IQ** — grounds a single agent in real enterprise context so it can reason and act reliably. You'll build **Caldova's supplier-assurance agent**: a context-aware **Agent 365 autopilot** grounded across all four IQs on **Caldova's own supplier performance, contract, and policy data**.

> **Storyline:** This is Chapter 01 — *"Ground"* — of the FY27 **Caldova** "Amplify Your Intelligence" narrative. Caldova is a global pharmaceutical company mid AI-transformation (the FY27 successor to Zava). The agent is grounded across **Web · Fabric · Foundry · Work IQ**, then the *same* IQ backbone powers the next agent with no new connectors.

### 🚀 Getting Started

#### In a Guided Session
If you're following along during a live session:
1. Sign in to Azure (`az login`) and the Azure Developer CLI (`azd auth login`).
2. Provision + seed + deploy with a single flow (see [`instructions/`](instructions/README.md)).
3. Open the [`instructions/`](instructions/README.md) folder and follow the step-by-step guidance.

#### On Your Own
If you're learning at your own pace:
1. Clone this repository.
2. Follow [`docs/setup.md`](docs/setup.md) to deploy and register the agent.
3. Walk the demos with [`delivery-resources/demos/README.md`](delivery-resources/demos/README.md).

### 🎯 Learning Outcomes

By the end of this session, you will be able to:

- Explain the four Microsoft IQs and the distinct enterprise context each provides to an agent.
- Wire Foundry IQ, Fabric IQ, Work IQ, and Web IQ into a single hosted agent as project-connection tools on the Responses API.
- Deploy the agent as a governed **Agent 365 autopilot** (digital worker) with its own identity, on-behalf-of auth, and observability.

### 🧩 The four IQs in this demo

| IQ | What it grounds | In this agent (Caldova) |
|:---|:---|:---|
| **Foundry IQ** | Reusable, permission-aware knowledge base | Caldova **policies, contracts, and quality/inspection documents** (4 knowledge sources) |
| **Fabric IQ** | Shared business meaning: data, definitions, rules & ontology | **Supplier performance** data in OneLake (OTIF, quality, regulatory, audit, financial) + ontology |
| **Work IQ** | Real-time work awareness: mail, meetings, chats & files | The agent's Microsoft 365 mailbox (reads + replies to a supply escalation) |
| **Web IQ** | Fresh, cited web intelligence | Real-time external supply / weather / carrier signals |

### 💻 Technologies Used

- [Microsoft Foundry](https://learn.microsoft.com/azure/ai-foundry/) — hosted agents (Responses API)
- [Microsoft IQ](https://aka.ms/microsoft-iq) — Foundry IQ, Fabric IQ, Work IQ, Web IQ
- [Microsoft Agent 365](https://aka.ms/agent365) — autopilot (digital worker) identity & governance
- [Microsoft Fabric](https://learn.microsoft.com/fabric/) — data agent + OneLake
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

### 📚 Continue Your Learning

| Resource | What You'll Get |
|----------|-----------------|
| **[Microsoft IQ](https://aka.ms/microsoft-iq)** | The unified intelligence platform for enterprise AI |
| **[Microsoft IQ Series](https://aka.ms/iq-series)** | Hands-on series going deeper on Foundry IQ, Fabric IQ, Work IQ, and Web IQ |
| **[Microsoft Learn](https://learn.microsoft.com)** | Official documentation and guided learning paths |
| **[AI Tour 2027 Resource Center](https://aka.ms/aitour27-resource-center)** | Additional session repos and materials from AI Tour 2027 |
| **[Microsoft Foundry Community](https://aka.ms/MicrosoftFoundryDiscord-AITour27)** | Connect with other learners and experts in our Discord community |

### 🌟 Microsoft Learn MCP Server

The Microsoft Learn MCP Server gives your AI agent direct access to Microsoft's official documentation — grounded, up-to-date answers about the topics in this session.

**GitHub Copilot CLI** — Install with:
```
copilot plugin install microsoftdocs/mcp
```

**VS Code** — One-click install:
[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Microsoft_Learn_MCP-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect/mcp/install?name=microsoft-learn&config=%7B%22type%22%3A%22http%22%2C%22url%22%3A%22https%3A%2F%2Flearn.microsoft.com%2Fapi%2Fmcp%22%7D)

For more information, visit the [Learn MCP Server repo](https://aka.ms/learnmcp).

### 👥 Content Owners

<table>
<tr>
    <td align="center"><a href="https://github.com/aycabas">
        <img src="https://github.com/aycabas.png" width="100px;" alt="Ayça Baş"/><br />
        <sub><b>Ayça Baş</b></sub></a><br />
            <a href="https://github.com/aycabas" title="talk">📢</a>
    </td>
    <td align="center"><a href="https://github.com/pamelafox">
        <img src="https://github.com/pamelafox.png" width="100px;" alt="Pamela Fox"/><br />
        <sub><b>Pamela Fox</b></sub></a><br />
            <a href="https://github.com/pamelafox" title="talk">📢</a>
    </td>
</tr></table>

If you will be delivering this session, see the [delivery-resources](delivery-resources/README.md) folder for the delivery checklist and presenter materials.

### 🤝 Contributing

This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit [Contributor License Agreements](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately. Simply follow the instructions provided by the bot. You will only need to do this once across all repos.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any questions or comments.

### ⚖️ Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.

Any use of third-party trademarks or logos are subject to those third-party's policies.
