# Sentinel MCP Demo — Brute Force & Compromised Account Investigation

A demo environment for showing how a **Microsoft Copilot agent** can autonomously investigate a brute force attack and account compromise using three MCP tools backed by real Sentinel data.

---

## What This Demo Does

A threat actor targets `david.brown@contoso.com` with a brute force attack from a Russian Tor exit node. After 26 failed attempts in under 5 minutes, the account is compromised. Fifteen minutes later the same account logs in from Beijing — physically impossible. Both IPs are known in threat intelligence feeds. The Copilot agent investigates everything end-to-end from a single prompt.

---

## Prerequisites

- An active **Azure subscription**
- **Microsoft Sentinel** workspace deployed (the scripts default to `CUS-Sentinel` in resource group `CUS-Sentinel`, Central US)
- **Azure CLI** (`az`) installed and logged in (`az login`)
- **PowerShell 7+**
- **Microsoft Defender portal** access (for creating MCP tools in Advanced Hunting)
- **Microsoft 365 Copilot** with agent builder access (for connecting the MCP collection)

---

## Step 1 — Create the Custom Log Tables

You need three custom tables in your Sentinel workspace before any data can be ingested.

Go to **Azure Portal** → your Log Analytics workspace → **Tables** → **Create** → **New custom log (DCR-based)**, or use the Azure CLI:

```powershell
$sub = "<your-subscription-id>"
$rg  = "<your-resource-group>"
$ws  = "<your-workspace-name>"

# Create AuthenticationEvents_CL
az monitor log-analytics workspace table create `
  --subscription $sub --resource-group $rg --workspace-name $ws `
  --name AuthenticationEvents_CL `
  --columns '[{"name":"TimeGenerated","type":"dateTime"},{"name":"UserPrincipalName","type":"string"},{"name":"SourceIP","type":"string"},{"name":"AuthResult","type":"string"},{"name":"AuthMethod","type":"string"},{"name":"UserAgent","type":"string"},{"name":"ApplicationName","type":"string"},{"name":"MFACompleted","type":"boolean"},{"name":"FailureReason","type":"string"},{"name":"SessionId","type":"string"}]'

# Create GeoIPLookup_CL
az monitor log-analytics workspace table create `
  --subscription $sub --resource-group $rg --workspace-name $ws `
  --name GeoIPLookup_CL `
  --columns '[{"name":"TimeGenerated","type":"dateTime"},{"name":"IPAddress","type":"string"},{"name":"Country","type":"string"},{"name":"City","type":"string"},{"name":"Latitude","type":"real"},{"name":"Longitude","type":"real"},{"name":"ISP","type":"string"},{"name":"ASN","type":"string"}]'

# Create ThreatIntelIOC_CL
az monitor log-analytics workspace table create `
  --subscription $sub --resource-group $rg --workspace-name $ws `
  --name ThreatIntelIOC_CL `
  --columns '[{"name":"TimeGenerated","type":"dateTime"},{"name":"IndicatorType","type":"string"},{"name":"IndicatorValue","type":"string"},{"name":"ThreatType","type":"string"},{"name":"Confidence","type":"int"},{"name":"Source","type":"string"},{"name":"FirstSeen","type":"dateTime"},{"name":"LastSeen","type":"dateTime"},{"name":"IsActive","type":"boolean"},{"name":"Description","type":"string"}]'
```

The JSON schema files in the `Tables/` folder are the reference definitions for each table.

---

## Step 2 — Create a Data Collection Endpoint (DCE)

The ingestion script pushes data via the Logs Ingestion API and needs a DCE.

```powershell
az monitor data-collection endpoint create `
  --name "dce-sentinel-demo" `
  --resource-group $rg `
  --location "centralus" `
  --public-network-access "Enabled"
```

Note the `id` from the output — you will need it in the next step.

---

## Step 3 — Create the Data Collection Rules (DCRs)

Each table needs its own DCR. The definitions are in the `DCR Rules/` folder. Before deploying, open each JSON file and replace:
- `<your-subscription-id>` — your Azure subscription ID
- `<your-resource-group>` — your resource group name
- `<your-workspace-name>` — your Log Analytics workspace name
- `<your-dce-name>` — the DCE name from Step 2

Then deploy all three:

```powershell
az deployment group create --resource-group $rg --template-file "DCR Rules/dcr_auth.json"
az deployment group create --resource-group $rg --template-file "DCR Rules/dcr_geoip.json"
az deployment group create --resource-group $rg --template-file "DCR Rules/dcr_threatintel.json"
```

After deployment, note the three DCR IDs (`dcr-xxxxxxxx`) from the Azure Portal under **Monitor** → **Data Collection Rules**. You will need them for the ingestion script.

---

## Step 4 — Ingest the Sample Data

Open `Sample Data/Ingest-SampleData.ps1` and update the configuration block at the top:

```powershell
$dceEndpoint = "https://<your-dce-endpoint>.ingest.monitor.azure.com"
$dcrAuthId   = "dcr-<auth-dcr-id>"
$dcrGeoIPId  = "dcr-<geoip-dcr-id>"
$dcrThreatId = "dcr-<threatintel-dcr-id>"
```

Then run the script:

```powershell
."Sample Data/Ingest-SampleData.ps1"
```

The script generates and ingests:
- ~50 legitimate login events across 5 users
- 26 brute force failures against `david.brown@contoso.com` from a Russian IP
- A successful compromise login, followed by an impossible travel login from China 15 minutes later
- Post-compromise access to Azure Portal, SharePoint, and M365 Admin without MFA
- GeoIP records for all IPs used
- Threat intelligence indicators for all attacker IPs

Allow **5–10 minutes** for data to appear in Sentinel after ingestion.

---

## Step 5 — Create the MCP Tools in Defender Portal

1. Go to **Microsoft Defender portal** → **Hunting** → **Advanced Hunting**
2. For each of the three tools below, paste the corresponding KQL from `MCP Tools & KQL/MCP-Tool-Definitions.kql`, click **Save as tool**, and fill in the details:

**Tool 1 — `detect_brute_force_compromise`**
- Collection: `BruteForceDemo` (create new)
- Default workspace: your Sentinel workspace name
- Parameters: `Threshold` (default: 20), `LookbackHours` (default: 24)

**Tool 2 — `detect_impossible_travel`**
- Collection: `BruteForceDemo`
- Default workspace: your Sentinel workspace name
- Parameters: `UserPrincipalName` (default: `*`), `TravelWindowMinutes` (default: 30)

**Tool 3 — `match_threat_intel_logins`**
- Collection: `BruteForceDemo`
- Default workspace: your Sentinel workspace name
- Parameters: `UserPrincipalName` (default: `*`), `MinConfidence` (default: 0)

Full tool descriptions and parameter descriptions are in `DEMO-STORYLINE.md` under **Setup Instructions**.

---

## Step 6 — Create the Copilot Agent

1. Go to **Microsoft 365 Copilot Studio** or the **Copilot agent builder** in M365
2. Create a new agent
3. Paste the contents of `instructions.md` as the agent's system instructions
4. Under **Actions**, connect the `BruteForceDemo` MCP collection from the Defender portal
5. Add the prompt files from the `prompts/` folder as suggested prompts (optional but recommended for demos)

---

## Step 7 — Run the Demo

Use the single prompt from `prompts/full-investigation.prompt.md` to trigger the full investigation in one shot, or walk through the individual act prompts for a step-by-step presentation.

The `DEMO-STORYLINE.md` file contains talking points and expected output for each act.

---

## Files Reference

| Path | Purpose |
|---|---|
| `instructions.md` | Copilot agent system instructions |
| `MCP Tools & KQL/MCP-Tool-Definitions.kql` | KQL for all three MCP tools (with `{Parameters}`) |
| `MCP Tools & KQL/SentinelMCP-KQL-Queries.kql` | Standalone KQL for direct testing in Advanced Hunting |
| `Sample Data/Ingest-SampleData.ps1` | Generates and ingests all demo data via Logs Ingestion API |
| `DCR Rules/dcr_auth.json` | DCR definition for `AuthenticationEvents_CL` |
| `DCR Rules/dcr_geoip.json` | DCR definition for `GeoIPLookup_CL` |
| `DCR Rules/dcr_threatintel.json` | DCR definition for `ThreatIntelIOC_CL` |
| `Tables/auth_table.json` | Table schema for `AuthenticationEvents_CL` |
| `Tables/geoip_table.json` | Table schema for `GeoIPLookup_CL` |
| `Tables/threatintel_table.json` | Table schema for `ThreatIntelIOC_CL` |
| `prompts/full-investigation.prompt.md` | Single-prompt full investigation |
| `prompts/detect-brute-force.prompt.md` | Act 1 prompt |
| `prompts/detect-impossible-travel.prompt.md` | Act 2 prompt |
| `prompts/match-threat-intel.prompt.md` | Act 3 prompt |
| `DEMO-STORYLINE.md` | Full demo script, expected results, and talking points |
