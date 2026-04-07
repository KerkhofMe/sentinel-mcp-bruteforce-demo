<#
.SYNOPSIS
    Generates sample data for the Brute Force & Compromised Account demo
    and ingests it via the Logs Ingestion API (DCR-based).
#>

# === Configuration ===
# Replace these values with your own after completing Steps 2-3 in README.md
$dceEndpoint   = "https://<your-dce-endpoint>.ingest.monitor.azure.com"
$dcrAuthId     = "dcr-<auth-dcr-immutable-id>"
$dcrGeoIPId    = "dcr-<geoip-dcr-immutable-id>"
$dcrThreatId   = "dcr-<threatintel-dcr-immutable-id>"
$streamAuth    = "Custom-AuthenticationEvents_CL"
$streamGeoIP   = "Custom-GeoIPLookup_CL"
$streamThreat  = "Custom-ThreatIntelIOC_CL"

# Get bearer token for Logs Ingestion API
$token = (az account get-access-token --resource "https://monitor.azure.com/" --query "accessToken" -o tsv)

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

# === Reference Data ===
$now = [DateTime]::UtcNow

# Legitimate users
$users = @(
    "alice.johnson@contoso.com",
    "bob.smith@contoso.com",
    "carol.williams@contoso.com",
    "david.brown@contoso.com",
    "emma.davis@contoso.com"
)

# The compromised user (target of brute force)
$targetUser = "david.brown@contoso.com"

# Legitimate IPs (US-based office locations)
$legitIPs = @("203.0.113.10", "203.0.113.11", "203.0.113.12", "198.51.100.20", "198.51.100.21")

# Attacker IPs
$attackerIP1 = "185.220.101.45"   # Brute force from Russia
$attackerIP2 = "91.234.56.78"     # Post-compromise login from China (impossible travel)
$knownMaliciousIPs = @("185.220.101.45", "91.234.56.78", "45.155.205.99", "194.26.29.100", "5.188.86.12")

$applications = @("Microsoft 365", "Azure Portal", "SharePoint Online", "Teams", "Outlook Web")
$userAgents = @(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0"
)
$attackerUA = "python-requests/2.31.0"

# === Generate GeoIP Lookup Data ===
Write-Host "Generating GeoIP data..." -ForegroundColor Cyan
$geoIPData = @(
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "203.0.113.10";   Country = "United States"; City = "Seattle";    Latitude = 47.6062;  Longitude = -122.3321; ISP = "Contoso Corp";       ASN = "AS64496" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "203.0.113.11";   Country = "United States"; City = "Seattle";    Latitude = 47.6062;  Longitude = -122.3321; ISP = "Contoso Corp";       ASN = "AS64496" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "203.0.113.12";   Country = "United States"; City = "Redmond";    Latitude = 47.6740;  Longitude = -122.1215; ISP = "Contoso Corp";       ASN = "AS64496" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "198.51.100.20";  Country = "United States"; City = "New York";   Latitude = 40.7128;  Longitude = -74.0060;  ISP = "Contoso Corp";       ASN = "AS64497" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "198.51.100.21";  Country = "United States"; City = "New York";   Latitude = 40.7128;  Longitude = -74.0060;  ISP = "Contoso Corp";       ASN = "AS64497" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "185.220.101.45"; Country = "Russia";        City = "Moscow";     Latitude = 55.7558;  Longitude = 37.6173;   ISP = "Bulletproof Host Ltd"; ASN = "AS44901" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "91.234.56.78";   Country = "China";         City = "Beijing";    Latitude = 39.9042;  Longitude = 116.4074;  ISP = "Shadow Networks";    ASN = "AS58879" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "45.155.205.99";  Country = "Netherlands";   City = "Amsterdam";  Latitude = 52.3676;  Longitude = 4.9041;    ISP = "Anon VPN Provider";  ASN = "AS209588" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "194.26.29.100";  Country = "Romania";       City = "Bucharest";  Latitude = 44.4268;  Longitude = 26.1025;   ISP = "DarkNet Hosting";    ASN = "AS39798" }
    @{ TimeGenerated = $now.ToString("o"); IPAddress = "5.188.86.12";    Country = "Russia";        City = "St Petersburg"; Latitude = 59.9343; Longitude = 30.3351;  ISP = "Storm VPS";          ASN = "AS34549" }
)

# === Generate Threat Intel IOC Data ===
Write-Host "Generating Threat Intel IOC data..." -ForegroundColor Cyan
$threatData = @(
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "185.220.101.45"; ThreatType = "BruteForce";    Confidence = 95; Source = "Microsoft MSTIC";    FirstSeen = $now.AddDays(-30).ToString("o"); LastSeen = $now.AddHours(-2).ToString("o"); IsActive = $true;  Description = "Known brute force source - Tor exit node" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "91.234.56.78";   ThreatType = "C2";            Confidence = 90; Source = "CrowdStrike Falcon";  FirstSeen = $now.AddDays(-15).ToString("o"); LastSeen = $now.AddHours(-1).ToString("o"); IsActive = $true;  Description = "Command and control server for credential theft" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "45.155.205.99";  ThreatType = "Proxy";         Confidence = 80; Source = "AlienVault OTX";      FirstSeen = $now.AddDays(-60).ToString("o"); LastSeen = $now.AddDays(-5).ToString("o");  IsActive = $true;  Description = "Anonymous proxy used in credential stuffing" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "194.26.29.100";  ThreatType = "BotNet";        Confidence = 85; Source = "Recorded Future";     FirstSeen = $now.AddDays(-45).ToString("o"); LastSeen = $now.AddDays(-1).ToString("o");  IsActive = $true;  Description = "Botnet node used for distributed brute force" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "5.188.86.12";    ThreatType = "Phishing";      Confidence = 70; Source = "VirusTotal";          FirstSeen = $now.AddDays(-20).ToString("o"); LastSeen = $now.AddDays(-3).ToString("o");  IsActive = $true;  Description = "Hosting phishing pages targeting M365" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "domain"; IndicatorValue = "evil-login.contoso-auth.com"; ThreatType = "Phishing"; Confidence = 92; Source = "Microsoft MSTIC"; FirstSeen = $now.AddDays(-10).ToString("o"); LastSeen = $now.AddDays(-1).ToString("o"); IsActive = $true; Description = "Phishing domain mimicking Contoso login" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "hash"; IndicatorValue = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"; ThreatType = "Malware"; Confidence = 88; Source = "VirusTotal"; FirstSeen = $now.AddDays(-7).ToString("o"); LastSeen = $now.AddDays(-1).ToString("o"); IsActive = $true; Description = "Credential harvesting tool hash" }
    @{ TimeGenerated = $now.ToString("o"); IndicatorType = "ipv4"; IndicatorValue = "103.45.67.89"; ThreatType = "Scanner"; Confidence = 60; Source = "Shodan"; FirstSeen = $now.AddDays(-90).ToString("o"); LastSeen = $now.AddDays(-30).ToString("o"); IsActive = $false; Description = "Historical scanner - no longer active" }
)

# === Generate Authentication Events ===
Write-Host "Generating Authentication Events..." -ForegroundColor Cyan
$authData = @()

# --- Phase 1: Normal legitimate activity (past 24h, ~50 events) ---
for ($i = 0; $i -lt 50; $i++) {
    $user = $users | Get-Random
    $ip = $legitIPs | Get-Random
    $app = $applications | Get-Random
    $ua = $userAgents | Get-Random
    $ts = $now.AddMinutes(-(Get-Random -Minimum 60 -Maximum 1440))

    $authData += @{
        TimeGenerated     = $ts.ToString("o")
        UserPrincipalName = $user
        SourceIP          = $ip
        AuthResult        = "Success"
        AuthMethod        = (@("Password+MFA", "SSO", "FIDO2") | Get-Random)
        UserAgent         = $ua
        ApplicationName   = $app
        MFACompleted      = $true
        FailureReason     = ""
        SessionId         = [guid]::NewGuid().ToString()
    }
}

# --- Phase 2: Brute force attack on david.brown (25 failures in 20 min window) ---
$bruteForceStart = $now.AddMinutes(-90)
for ($i = 0; $i -lt 25; $i++) {
    $ts = $bruteForceStart.AddSeconds((Get-Random -Minimum 0 -Maximum 1200))
    $failReason = @("Invalid password", "Account locked", "Invalid password", "Invalid password", "Throttled") | Get-Random

    $authData += @{
        TimeGenerated     = $ts.ToString("o")
        UserPrincipalName = $targetUser
        SourceIP          = $attackerIP1
        AuthResult        = "Failure"
        AuthMethod        = "Password"
        UserAgent         = $attackerUA
        ApplicationName   = "Microsoft 365"
        MFACompleted      = $false
        FailureReason     = $failReason
        SessionId         = [guid]::NewGuid().ToString()
    }
}

# --- Phase 3: Successful brute force (attacker gets in from Russia) ---
$compromiseTime = $bruteForceStart.AddMinutes(22)
$authData += @{
    TimeGenerated     = $compromiseTime.ToString("o")
    UserPrincipalName = $targetUser
    SourceIP          = $attackerIP1
    AuthResult        = "Success"
    AuthMethod        = "Password"
    UserAgent         = $attackerUA
    ApplicationName   = "Microsoft 365"
    MFACompleted      = $false
    FailureReason     = ""
    SessionId         = [guid]::NewGuid().ToString()
}

# --- Phase 4: Impossible travel - login from China 15 min after Russia login ---
$impossibleTravelTime = $compromiseTime.AddMinutes(15)
$authData += @{
    TimeGenerated     = $impossibleTravelTime.ToString("o")
    UserPrincipalName = $targetUser
    SourceIP          = $attackerIP2
    AuthResult        = "Success"
    AuthMethod        = "Password"
    UserAgent         = $attackerUA
    ApplicationName   = "Azure Portal"
    MFACompleted      = $false
    FailureReason     = ""
    SessionId         = [guid]::NewGuid().ToString()
}

# --- Phase 5: Post-compromise activity (attacker browsing resources from China) ---
for ($i = 0; $i -lt 8; $i++) {
    $ts = $impossibleTravelTime.AddMinutes((Get-Random -Minimum 1 -Maximum 60))
    $app = @("Azure Portal", "SharePoint Online", "Microsoft 365 Admin") | Get-Random

    $authData += @{
        TimeGenerated     = $ts.ToString("o")
        UserPrincipalName = $targetUser
        SourceIP          = $attackerIP2
        AuthResult        = "Success"
        AuthMethod        = "Password"
        UserAgent         = $attackerUA
        ApplicationName   = $app
        MFACompleted      = $false
        FailureReason     = ""
        SessionId         = [guid]::NewGuid().ToString()
    }
}

# --- Phase 6: Scatter some failed logins from other malicious IPs (noise) ---
for ($i = 0; $i -lt 15; $i++) {
    $user = $users | Get-Random
    $ip = $knownMaliciousIPs | Get-Random
    $ts = $now.AddMinutes(-(Get-Random -Minimum 60 -Maximum 1440))

    $authData += @{
        TimeGenerated     = $ts.ToString("o")
        UserPrincipalName = $user
        SourceIP          = $ip
        AuthResult        = "Failure"
        AuthMethod        = "Password"
        UserAgent         = $attackerUA
        ApplicationName   = "Microsoft 365"
        MFACompleted      = $false
        FailureReason     = "Invalid password"
        SessionId         = [guid]::NewGuid().ToString()
    }
}

# --- Phase 7: Legitimate login from david.brown from his normal IP (for contrast) ---
$authData += @{
    TimeGenerated     = $now.AddHours(-6).ToString("o")
    UserPrincipalName = $targetUser
    SourceIP          = "198.51.100.20"
    AuthResult        = "Success"
    AuthMethod        = "Password+MFA"
    UserAgent         = $userAgents[0]
    ApplicationName   = "Microsoft 365"
    MFACompleted      = $true
    FailureReason     = ""
    SessionId         = [guid]::NewGuid().ToString()
}

Write-Host "Generated $($authData.Count) auth events, $($geoIPData.Count) GeoIP records, $($threatData.Count) threat IOCs" -ForegroundColor Green

# === Ingest Function ===
function Send-LogsIngestion {
    param(
        [string]$DcrImmutableId,
        [string]$StreamName,
        [array]$Data,
        [string]$Label
    )

    $uri = "$dceEndpoint/dataCollectionRules/$DcrImmutableId/streams/${StreamName}?api-version=2023-01-01"
    $body = $Data | ConvertTo-Json -Depth 10

    # Ensure it's always an array
    if ($Data.Count -eq 1) {
        $body = "[$body]"
    }

    Write-Host "Ingesting $($Data.Count) records to $Label..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -StatusCodeVariable "statusCode"
        Write-Host "  -> ${Label}: HTTP ${statusCode} - Success" -ForegroundColor Green
    }
    catch {
        $errMsg = $_.Exception.Message
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "  -> ${Label}: HTTP ${statusCode} - ${errMsg}" -ForegroundColor Red
        if ($_.ErrorDetails) { Write-Host "     Details: $($_.ErrorDetails.Message)" -ForegroundColor Red }
    }
}

# === Ingest All Data ===
Write-Host "`n=== Starting Ingestion via Logs Ingestion API ===" -ForegroundColor Cyan

Send-LogsIngestion -DcrImmutableId $dcrAuthId    -StreamName $streamAuth   -Data $authData    -Label "AuthenticationEvents_CL"
Send-LogsIngestion -DcrImmutableId $dcrGeoIPId   -StreamName $streamGeoIP  -Data $geoIPData   -Label "GeoIPLookup_CL"
Send-LogsIngestion -DcrImmutableId $dcrThreatId  -StreamName $streamThreat -Data $threatData   -Label "ThreatIntelIOC_CL"

Write-Host "`n=== Ingestion Complete ===" -ForegroundColor Green
Write-Host "Note: Data may take 5-10 minutes to appear in Log Analytics." -ForegroundColor Yellow
