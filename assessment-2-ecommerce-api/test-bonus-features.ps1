# Bonus Features Test Suite
# Tests all advanced features: Metrics, Fuzzy Search, Export, Recommendations

$baseUrl = "http://localhost:3002"
$token = "bonus-test-token-$(Get-Random)"
$testsPassed = 0
$testsFailed = 0

function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    Write-Host "`n► Testing: $Name" -ForegroundColor Cyan
    try {
        & $TestBlock
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        $global:testsPassed++
    } catch {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        $global:testsFailed++
    }
}

# ============================================================================
# TEST 1: METRICS ENDPOINT
# ============================================================================

Test-Feature "Metrics Endpoint - Authentication Required" {
    $response = Invoke-WebRequest -Uri "$baseUrl/admin/metrics" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $data = $response.Content | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($data.requests.total)) { throw "Missing requests.total" }
    if ([string]::IsNullOrEmpty($data.performance.avgResponseTime)) { throw "Missing avgResponseTime" }
    if ([string]::IsNullOrEmpty($data.uptime)) { throw "Missing uptime" }
}

Test-Feature "Metrics Endpoint - Request Count Tracking" {
    # Make some requests
    Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing | Out-Null
    Invoke-WebRequest -Uri "$baseUrl/api/products?limit=1" -UseBasicParsing | Out-Null
    
    Start-Sleep -Milliseconds 500
    
    $response = Invoke-WebRequest -Uri "$baseUrl/admin/metrics" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.requests.total -lt 1) { throw "Request count too low: $($data.requests.total)" }
}

Test-Feature "Metrics Endpoint - Endpoint Stats" {
    $response = Invoke-WebRequest -Uri "$baseUrl/admin/metrics" `
        -Headers @{ Authorization = "Bearer $token" } `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.endpoints.Count -lt 1) { throw "No endpoints tracked" }
    
    $endpoint = $data.endpoints[0]
    if ([string]::IsNullOrEmpty($endpoint.endpoint)) { throw "Missing endpoint name" }
    if ($endpoint.count -lt 1) { throw "Invalid endpoint count" }
    if ($endpoint.avgTime -lt 0) { throw "Invalid avgTime" }
}

Test-Feature "Metrics Endpoint - No Auth = 401" {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/admin/metrics" `
            -UseBasicParsing -ErrorAction Stop
        throw "Should have failed with 401"
    } catch {
        if ($_.Exception.Response.StatusCode -ne 401) {
            throw "Expected 401, got $($_.Exception.Response.StatusCode)"
        }
    }
}

# ============================================================================
# TEST 2: FUZZY SEARCH
# ============================================================================

Test-Feature "Fuzzy Search - Basic Search Works" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products?search=product`&limit=5" `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.products.Count -lt 1) { throw "No products found" }
    if ($data.pagination.totalItems -lt 1) { throw "Invalid total items" }
}

Test-Feature "Fuzzy Search - Fuzzy Flag Enabled" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products?search=product`&fuzzy=true`&limit=5" `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.products.Count -lt 1) { throw "No products found with fuzzy=true" }
}

Test-Feature "Fuzzy Search - Returns Public Fields Only" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products?search=product`&limit=1" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    $product = $data.products[0]
    
    # Check public fields exist
    if ([string]::IsNullOrEmpty($product.id)) { throw "Missing id" }
    if ([string]::IsNullOrEmpty($product.name)) { throw "Missing name" }
    if ($null -eq $product.price) { throw "Missing price" }
    if ([string]::IsNullOrEmpty($product.category)) { throw "Missing category" }
    if ([string]::IsNullOrEmpty($product.brand)) { throw "Missing brand" }
    
    # Check sensitive fields NOT present
    if ($product.PSObject.Properties.Name -contains "costPrice") { throw "costPrice exposed!" }
    if ($product.PSObject.Properties.Name -contains "supplier") { throw "supplier exposed!" }
}

Test-Feature "Fuzzy Search - Category Filter Works" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products?category=Electronics`&limit=5" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    
    # Verify all results are in Electronics category
    foreach ($product in $data.products) {
        if ($product.category -ne "Electronics") {
            throw "Product $($product.id) not in Electronics: $($product.category)"
        }
    }
}

Test-Feature "Fuzzy Search - Pagination Works" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products?page=1`&limit=5" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.pagination.currentPage -ne 1) { throw "Page mismatch" }
    if ($data.pagination.itemsPerPage -ne 5) { throw "Limit mismatch" }
    if ($data.products.Count -gt 5) { throw "Too many results" }
}

# ============================================================================
# TEST 3: PRODUCT EXPORT
# ============================================================================

Test-Feature "Export - JSON Format - All Products" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=json" `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $data = $response.Content | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($data.format)) { throw "Missing format field" }
    if ($data.format -ne "json") { throw "Format not json" }
    if ([string]::IsNullOrEmpty($data.exportDate)) { throw "Missing exportDate" }
    if ($data.totalProducts -lt 100) { throw "Expected many products, got $($data.totalProducts)" }
    if ($data.products.Count -lt 1) { throw "No products in export" }
}

Test-Feature "Export - JSON Format - Filtered by Category" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=json`&category=Sports" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.category -ne "Sports") { throw "Category mismatch" }
    
    # Verify all exported products are in Sports
    foreach ($product in $data.products) {
        if ($product.category -ne "Sports") {
            throw "Product $($product.id) not in Sports category"
        }
    }
}

Test-Feature "Export - CSV Format Works" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=csv`&category=Clothing" `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $csv = $response.Content
    $lines = $csv -split "`n"
    
    if ($lines.Count -lt 2) { throw "CSV too short (needs header + data)" }
    if (-not $lines[0].Contains("id,name,description")) { throw "Invalid CSV header" }
}

Test-Feature "Export - CSV Has Correct Headers" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=csv" `
        -UseBasicParsing
    
    $csv = $response.Content
    $header = ($csv -split "`n")[0]
    
    $requiredFields = @("id", "name", "description", "price", "category", "brand", "stock", "rating", "tags")
    foreach ($field in $requiredFields) {
        if (-not $header.Contains($field)) {
            throw "Missing field in CSV header: $field"
        }
    }
}

Test-Feature "Export - Invalid Format Returns Error" {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/products/export?format=xml" `
            -UseBasicParsing -ErrorAction Stop
        throw "Should have returned 400 for invalid format"
    } catch {
        if ($_.Exception.Response.StatusCode -ne 400) {
            throw "Expected 400, got $($_.Exception.Response.StatusCode)"
        }
    }
}

# ============================================================================
# TEST 4: PRODUCT RECOMMENDATIONS
# ============================================================================

Test-Feature "Recommendations - Basic Endpoint Works" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/1/recommendations" `
        -UseBasicParsing
    
    if ($response.StatusCode -ne 200) { throw "Expected 200, got $($response.StatusCode)" }
    
    $data = $response.Content | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($data.baseProduct.id)) { throw "Missing baseProduct" }
    if ($null -eq $data.recommendations) { throw "Missing recommendations" }
}

Test-Feature "Recommendations - Returns Relevance Scores" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/50/recommendations?limit=5" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.recommendations.Count -lt 1) { throw "No recommendations returned" }
    
    foreach ($rec in $data.recommendations) {
        if ($null -eq $rec.relevanceScore) { throw "Missing relevanceScore" }
        if ($rec.relevanceScore -lt 0 -or $rec.relevanceScore -gt 100) {
            throw "Invalid relevanceScore: $($rec.relevanceScore)"
        }
    }
}

Test-Feature "Recommendations - Highest Score First" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/100/recommendations?limit=5" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    
    # Verify descending order by relevance score
    for ($i = 0; $i -lt ($data.recommendations.Count - 1); $i++) {
        $current = $data.recommendations[$i].relevanceScore
        $next = $data.recommendations[$i + 1].relevanceScore
        
        if ($current -lt $next) {
            throw "Recommendations not sorted by score (descending): $current > $next"
        }
    }
}

Test-Feature "Recommendations - Respects Limit Parameter" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/1/recommendations?limit=3" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.recommendations.Count -gt 3) {
        throw "Returned more than limit: $($data.recommendations.Count) is greater than 3"
    }
}

Test-Feature "Recommendations - Max Limit Enforced" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/1/recommendations?limit=100" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.recommendations.Count -gt 20) {
        throw "Limit over 20 not enforced: $($data.recommendations.Count)"
    }
}

Test-Feature "Recommendations - Only Public Fields Returned" {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/products/1/recommendations?limit=1" `
        -UseBasicParsing
    
    $data = $response.Content | ConvertFrom-Json
    if ($data.recommendations.Count -lt 1) { throw "No recommendations" }
    
    $rec = $data.recommendations[0]
    
    # Check sensitive fields NOT present
    if ($rec.PSObject.Properties.Name -contains "costPrice") { throw "costPrice exposed!" }
    if ($rec.PSObject.Properties.Name -contains "supplier") { throw "supplier exposed!" }
    if ($rec.PSObject.Properties.Name -contains "internalNotes") { throw "internalNotes exposed!" }
}

Test-Feature "Recommendations - Invalid Product ID Returns Error" {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/products/99999/recommendations" `
            -UseBasicParsing -ErrorAction Stop
        throw "Should have returned 404"
    } catch {
        if ($_.Exception.Response.StatusCode -ne 404) {
            throw "Expected 404, got $($_.Exception.Response.StatusCode)"
        }
    }
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n`n" -ForegroundColor Cyan
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         BONUS FEATURES TEST RESULTS               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ ALL TESTS PASSED - Bonus Features Ready!" -ForegroundColor Green
} else {
    Write-Host "✗ Some tests failed - review output above" -ForegroundColor Red
}

Write-Host ""
Write-Host "Coverage:"
Write-Host "  - Metrics Endpoint: 4 tests"
Write-Host "  - Fuzzy Search: 5 tests"
Write-Host "  - Product Export: 5 tests"
Write-Host "  - Recommendations: 7 tests"
Write-Host ""
