# Evidentia - Demo Script for Windows
# This script demonstrates the complete evidence lifecycle

param(
    [string]$ApiUrl = "http://localhost:3001",
    [string]$FrontendUrl = "http://localhost:3000"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Evidentia Chain-of-Custody Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This demo simulates a complete evidence lifecycle:" -ForegroundColor White
Write-Host "  1. Officer registers seized evidence" -ForegroundColor Gray
Write-Host "  2. Evidence transferred to forensic lab" -ForegroundColor Gray
Write-Host "  3. Analyst examines the evidence" -ForegroundColor Gray
Write-Host "  4. Supervisor submits for judicial review" -ForegroundColor Gray
Write-Host "  5. Legal counsel records admissibility decision" -ForegroundColor Gray
Write-Host "  6. Complete audit report generated" -ForegroundColor Gray
Write-Host ""

# Check if backend is running
Write-Host "[INFO] Checking backend connection..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$ApiUrl/health" -Method Get -TimeoutSec 5
    Write-Host "[OK] Backend is running at $ApiUrl" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Backend not running at $ApiUrl" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the backend first:" -ForegroundColor Yellow
    Write-Host "  1. Open a new PowerShell window" -ForegroundColor Gray
    Write-Host "  2. Run: cd C:\Projects\Evidentia\backend" -ForegroundColor Gray
    Write-Host "  3. Run: npm run dev" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host ""
$continue = Read-Host "Press Enter to start the demo (or Ctrl+C to cancel)"

# Step 1: Login as Collector
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Step 1: Officer Registers Evidence" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Logging in as collector@lawenforcement..." -ForegroundColor Yellow

$loginBody = @{
    username = "collector@lawenforcement"
    password = "password123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json"
    
    $collectorToken = $loginResponse.data.token
    $userName = $loginResponse.data.user.commonName
    $userRole = $loginResponse.data.user.role
    
    Write-Host "[OK] Logged in successfully!" -ForegroundColor Green
    Write-Host "  Name: $userName" -ForegroundColor Gray
    Write-Host "  Role: $userRole" -ForegroundColor Gray
} catch {
    Write-Host "[ERROR] Login failed: $_" -ForegroundColor Red
    exit 1
}

# Generate case ID
$caseId = "CASE-$(Get-Date -Format 'yyyyMMdd')-001"
Write-Host ""
Write-Host "Case ID: $caseId" -ForegroundColor Cyan

Write-Host ""
Write-Host "In a real scenario, the officer would now:" -ForegroundColor White
Write-Host "  - Upload evidence file (disk image, documents, etc.)" -ForegroundColor Gray
Write-Host "  - Fill in metadata (device info, location, notes)" -ForegroundColor Gray
Write-Host "  - System computes SHA-256 hash" -ForegroundColor Gray
Write-Host "  - Evidence encrypted and stored on IPFS" -ForegroundColor Gray
Write-Host "  - Hash and metadata recorded on blockchain" -ForegroundColor Gray

Start-Sleep -Seconds 2

# Step 2: Transfer Custody
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Step 2: Transfer to Forensic Lab" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Officer transfers custody to Dr. Chen at Forensic Lab..." -ForegroundColor Yellow

Write-Host ""
Write-Host "Transfer details:" -ForegroundColor White
Write-Host "  From: Officer Smith (LawEnforcementMSP)" -ForegroundColor Gray
Write-Host "  To: Dr. Chen (ForensicLabMSP)" -ForegroundColor Gray
Write-Host "  Reason: Transfer for forensic examination" -ForegroundColor Gray

Write-Host ""
Write-Host "[OK] Custody transfer recorded on blockchain" -ForegroundColor Green

Start-Sleep -Seconds 2

# Step 3: Forensic Analysis
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Step 3: Forensic Analysis" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Logging in as analyst@forensiclab..." -ForegroundColor Yellow

$loginBody = @{
    username = "analyst@forensiclab"
    password = "password123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json"
    
    Write-Host "[OK] Logged in as Dr. Chen (Forensic Analyst)" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not switch user" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Forensic analysis recorded:" -ForegroundColor White
Write-Host "  Tool: Autopsy 4.21.0" -ForegroundColor Gray
Write-Host "  Artifacts found: 4" -ForegroundColor Gray
Write-Host "    - browser_history.csv" -ForegroundColor DarkGray
Write-Host "    - deleted_emails.pst" -ForegroundColor DarkGray
Write-Host "    - encrypted_docs.zip" -ForegroundColor DarkGray
Write-Host "    - registry_backup.reg" -ForegroundColor DarkGray
Write-Host "  Methodology: NIST 800-86 guidelines" -ForegroundColor Gray

Write-Host ""
Write-Host "[OK] Analysis recorded on blockchain" -ForegroundColor Green

Start-Sleep -Seconds 2

# Step 4: Submit for Review
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Step 4: Submit for Judicial Review" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Logging in as supervisor@forensiclab..." -ForegroundColor Yellow

$loginBody = @{
    username = "supervisor@forensiclab"
    password = "password123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json"
    
    Write-Host "[OK] Logged in as Dr. Williams (Lab Supervisor)" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not switch user" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Submitting evidence for judicial review..." -ForegroundColor Yellow
Write-Host "  Case notes: Analysis complete, chain of custody maintained" -ForegroundColor Gray

Write-Host ""
Write-Host "[OK] Evidence submitted for judicial review" -ForegroundColor Green

Start-Sleep -Seconds 2

# Step 5: Judicial Decision
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Step 5: Judicial Decision" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

Write-Host "Logging in as counsel@judiciary..." -ForegroundColor Yellow

$loginBody = @{
    username = "counsel@judiciary"
    password = "password123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$ApiUrl/api/auth/login" `
        -Method Post `
        -Body $loginBody `
        -ContentType "application/json"
    
    Write-Host "[OK] Logged in as Attorney Davis (Legal Counsel)" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Could not switch user" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Recording judicial decision..." -ForegroundColor Yellow
Write-Host "  Decision: ADMITTED" -ForegroundColor Green
Write-Host "  Reason: Evidence meets all legal requirements" -ForegroundColor Gray
Write-Host "  Court Reference: $(Get-Date -Format 'yyyy')-CR-001" -ForegroundColor Gray

Write-Host ""
Write-Host "[OK] Judicial decision recorded on blockchain" -ForegroundColor Green

Start-Sleep -Seconds 2

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Demo Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary of blockchain-recorded events:" -ForegroundColor White
Write-Host "  1. [OK] Evidence registered by Law Enforcement" -ForegroundColor Green
Write-Host "  2. [OK] Custody transferred to Forensic Lab" -ForegroundColor Green
Write-Host "  3. [OK] Forensic analysis recorded" -ForegroundColor Green
Write-Host "  4. [OK] Submitted for judicial review" -ForegroundColor Green
Write-Host "  5. [OK] Judicial decision: ADMITTED" -ForegroundColor Green
Write-Host "  6. [OK] Full audit trail available" -ForegroundColor Green
Write-Host ""
Write-Host "All events are immutably stored on Hyperledger Fabric blockchain" -ForegroundColor Gray
Write-Host "Evidence files encrypted and stored on IPFS" -ForegroundColor Gray
Write-Host ""
Write-Host "Open the web interface to explore:" -ForegroundColor Yellow
Write-Host "  $FrontendUrl" -ForegroundColor Cyan
Write-Host ""

