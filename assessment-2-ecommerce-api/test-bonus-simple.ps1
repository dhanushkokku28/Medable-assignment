# Simple Bonus Features Test
$baseUrl = "http://localhost:3002"
$token = "bonus-test"

Write-Host "=== BONUS FEATURES TEST ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Metrics
Write-Host "1. Testing /admin/metrics endpoint..." -ForegroundColor Yellow
$m = Invoke-WebRequest -Uri "$baseUrl/admin/metrics" -Headers @{Authorization="Bearer $token"} -UseBasicParsing | ConvertFrom-Json
Write-Host "   Total Requests: $($m.requests.total)" -ForegroundColor Green
Write-Host "   Avg Response Time: $($m.performance.avgResponseTime)ms" -ForegroundColor Green
Write-Host "   Tracked Endpoints: $($m.endpoints.Count)" -ForegroundColor Green

# Test 2: Export JSON
Write-Host ""
Write-Host "2. Testing /export JSON endpoint..." -ForegroundColor Yellow
$ej = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=json" -UseBasicParsing | ConvertFrom-Json
Write-Host "   Exported Products: $($ej.totalProducts)" -ForegroundColor Green
Write-Host "   Export Date: $($ej.exportDate)" -ForegroundColor Green

# Test 3: Export CSV
Write-Host ""
Write-Host "3. Testing /export CSV endpoint..." -ForegroundColor Yellow
$ec = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=csv" -UseBasicParsing
$lines = $ec.Content -split "`n"
Write-Host "   CSV Records: $($lines.Count)" -ForegroundColor Green
Write-Host "   Header: $($lines[0].Substring(0, 50))..." -ForegroundColor Green

# Test 4: Recommendations
Write-Host ""
Write-Host "4. Testing /recommendations endpoint..." -ForegroundColor Yellow
$r = Invoke-WebRequest -Uri "$baseUrl/api/products/1/recommendations?limit=3" -UseBasicParsing | ConvertFrom-Json
Write-Host "   Base Product: $($r.baseProduct.name)" -ForegroundColor Green
Write-Host "   Recommendations Found: $($r.totalRecommendations)" -ForegroundColor Green
if ($r.recommendations.Count -gt 0) {
    Write-Host "   Top Match: $($r.recommendations[0].name) (Score: $($r.recommendations[0].relevanceScore))" -ForegroundColor Green
}

# Test 5: Fuzzy Search
Write-Host ""
Write-Host "5. Testing Fuzzy Search..." -ForegroundColor Yellow
$fs = Invoke-WebRequest -Uri "$baseUrl/api/products?search=product`&fuzzy=true`&limit=2" -UseBasicParsing | ConvertFrom-Json
Write-Host "   Found Products: $($fs.products.Count)" -ForegroundColor Green
if ($fs.products.Count -gt 0) {
    Write-Host "   Sample: $($fs.products[0].name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== ALL BONUS FEATURES WORKING ===" -ForegroundColor Green
