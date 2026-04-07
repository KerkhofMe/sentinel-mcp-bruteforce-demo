# Sentinel MCP Demo — Brute Force & Compromised Account Investigation

## Scenario Overview

**Storyline:** A threat actor targets `david.brown@contoso.com` with a brute force attack from a Russian IP (`185.220.101.45`). After 25+ failed attempts, the attacker successfully compromises the account. Within 15 minutes, the same account is used from a Chinese IP (`91.234.56.78`) — an impossible travel event. The attacker then browses Azure Portal, SharePoint, and M365 Admin without MFA.

---

## Demo Flow — 3 Acts

### Act 1: "We've been alerted — is someone brute forcing our accounts?"

**MCP Tool:** `detect_brute_force_compromise`  
**Prompt to agent:**
> "Check if any accounts were brute forced in the last 24 hours with at least 20 failed attempts."

**Expected result:**
| Field | Value |
|---|---|
| User | david.brown@contoso.com |
| Failed Attempts | 26 |
| Attack Duration | ~4 min |
| Attacker IPs | 185.220.101.45, 45.155.205.99 |
| Failure Reasons | Invalid password, Account locked, Throttled |

**Talking points:**
- 26 failed logins in under 5 minutes → automated attack
- Attacker succeeded — this is a **confirmed compromise**
- User agent is `python-requests/2.31.0` — scripted, not a human

---

### Act 2: "Where is the attacker operating from? Is this physically possible?"

**MCP Tool:** `detect_impossible_travel`  
**Prompt to agent:**
> "Check if david.brown@contoso.com shows any impossible travel in the last 24 hours."

**Expected result:**
| Field | Value |
|---|---|
| Login 1 | Moscow, Russia → 185.220.101.45 |
| Login 2 | Beijing, China → 91.234.56.78 |
| Time between logins | 15 minutes |
| Distance | 5,794 km |
| Required speed | 23,176 km/h |

**Talking points:**
- Moscow → Beijing in 15 minutes requires **23,176 km/h** (Mach 19!)
- This is physically impossible → confirms **multiple attacker nodes** or **VPN/proxy hopping**
- Legitimate david.brown logged in 6 hours earlier from New York (US) with MFA ✓

---

### Act 3: "Are these IPs known to threat intelligence?"

**MCP Tool:** `match_threat_intel_logins`  
**Prompt to agent:**
> "Cross-reference david.brown's successful logins against our threat intelligence feed."

**Expected result:**
| IP | Country | Threat Type | Confidence | Source | Description |
|---|---|---|---|---|---|
| 185.220.101.45 | Russia | BruteForce | 95 | Microsoft MSTIC | Known brute force source - Tor exit node |
| 91.234.56.78 | China | C2 | 90 | CrowdStrike Falcon | Command and control server for credential theft |

**Talking points:**
- Attacker IP `185.220.101.45` is a known **Tor exit node** used for brute force (MSTIC, 95% confidence)
- Post-compromise IP `91.234.56.78` is flagged as a **C2 server** for credential theft (CrowdStrike, 90%)
- All successful logins from malicious IPs had **MFA = false** — account had weak auth
- The attacker accessed **Azure Portal**, **SharePoint**, and **M365 Admin** — potential lateral movement

---

## Setup Instructions — Creating MCP Tools in Defender Portal

### Step 1: Open Advanced Hunting
1. Go to **Microsoft Defender portal** → **Hunting** → **Advanced hunting**

### Step 2: Create Tool 1 — `detect_brute_force_compromise`
1. Paste the KQL from `MCP-Tool-Definitions.kql` (Tool 1) into the query editor
2. Click **Save as tool** (from query box menu or context menu)
3. Fill in:
   - **Name:** `detect_brute_force_compromise`
   - **Description:** "Detects brute force attacks where an account received a high number of failed login attempts followed by a successful login within a short time window. Returns the compromised user, attack duration, attacker IPs, and failure reasons. Use this tool first to identify compromised accounts."
   - **Collection:** Create new → `BruteForceDemo`
   - **Default workspace:** `<your-workspace-name>`
   - **Parameters:**
     - `Threshold` — "Minimum number of failed login attempts to trigger detection (default: 20)"
     - `LookbackHours` — "Number of hours to look back for events (default: 24)"
4. Click **Save**

### Step 3: Create Tool 2 — `detect_impossible_travel`
1. Paste the KQL from `MCP-Tool-Definitions.kql` (Tool 2)
2. **Save as tool** with:
   - **Name:** `detect_impossible_travel`
   - **Description:** "Detects impossible travel by finding users who logged in from two different countries within a short time window. Calculates distance and required speed. Use this tool after detect_brute_force_compromise to check if a compromised account shows impossible travel."
   - **Collection:** `BruteForceDemo`
   - **Default workspace:** `<your-workspace-name>`
   - **Parameters:**
     - `UserPrincipalName` — "The user principal name to investigate, or '*' for all users"
     - `TravelWindowMinutes` — "Maximum minutes between logins to flag as impossible travel (default: 30)"
3. Click **Save**

### Step 4: Create Tool 3 — `match_threat_intel_logins`
1. Paste the KQL from `MCP-Tool-Definitions.kql` (Tool 3)
2. **Save as tool** with:
   - **Name:** `match_threat_intel_logins`
   - **Description:** "Cross-references successful login IPs against active threat intelligence indicators. Returns threat type, confidence, source feed, and geo-location. Use this tool to enrich findings from detect_brute_force_compromise with threat context."
   - **Collection:** `BruteForceDemo`
   - **Default workspace:** `<your-workspace-name>`
   - **Parameters:**
     - `UserPrincipalName` — "The user principal name to investigate, or '*' for all users"
     - `MinConfidence` — "Minimum threat intelligence confidence score to include (default: 0)"
3. Click **Save**

### Step 5: Connect Collection to VS Code
Add to your VS Code MCP config (`.vscode/mcp.json` or settings):
```json
{
  "servers": {
    "sentinel-bruteforce-demo": {
      "type": "sse",
      "url": "https://sentinel.microsoft.com/mcp/BruteForceDemo",
      "headers": {
        "Authorization": "Bearer {{microsoft_auth}}"
      }
    }
  }
}
```

---

## Demo Script (Copy-Paste Prompts)

### Full Investigation — Single Prompt
```
Run a complete brute force investigation for the last 24 hours. 
First, detect any accounts that were brute forced with at least 20 failed login attempts. 
Then check whether the compromised account shows impossible travel patterns within 30 minutes. 
Finally, cross-reference all successful login IPs against our threat intelligence feed. 
Conclude with a full incident summary: attack timeline, attacker infrastructure, risk assessment, and recommended response actions.
```

---

### Prompt 1 — Detect the attack
```
Are there any brute force attacks in the last 24 hours? Look for accounts with 
at least 20 failed login attempts followed by a successful login.
```

### Prompt 2 — Check for impossible travel
```
The compromised user is david.brown@contoso.com. Check if this account shows 
any impossible travel patterns — logins from different countries within 30 minutes.
```

### Prompt 3 — Enrich with threat intel
```
Cross-reference all of david.brown's successful logins against our threat 
intelligence feed. What do we know about the attacker infrastructure?
```

### Prompt 4 — Summarize (agent reasoning)
```
Based on all the findings, give me a full incident summary for david.brown@contoso.com. 
Include the attack timeline, attacker infrastructure, risk assessment, and 
recommended response actions.
```

---

## Files in This Demo

| File | Purpose |
|---|---|
| `MCP-Tool-Definitions.kql` | KQL queries with `{Parameters}` for Defender portal "Save as tool" |
| `SentinelMCP-KQL-Queries.kql` | Standalone KQL queries (no parameters, for direct testing) |
| `Ingest-SampleData.ps1` | Script to generate and ingest sample data via Logs Ingestion API |
| `dcr_auth.json` | DCR definition for AuthenticationEvents_CL |
| `dcr_geoip.json` | DCR definition for GeoIPLookup_CL |
| `dcr_threatintel.json` | DCR definition for ThreatIntelIOC_CL |
| `auth_table.json` | Table schema for AuthenticationEvents_CL |
| `geoip_table.json` | Table schema for GeoIPLookup_CL |
| `threatintel_table.json` | Table schema for ThreatIntelIOC_CL |
