#!/usr/bin/env pwsh

# E-commerce API Test Script
Write-Host "====== E-Commerce API Test Suite ======" -ForegroundColor Green

$baseUrl = "http://localhost:3002"
$testToken = "test-token-12345"

# Test 1: Health Check
Write-Host "`n[Test 1] Health Check" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/health" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Health check passed: $($response.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ Health check failed: $_" -ForegroundColor Red
}

# Test 2: Get Products
Write-Host "`n[Test 2] Get Products (Public endpoint)" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products?limit=5" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Retrieved $($response.products.Count) products of $($response.pagination.totalItems) total" -ForegroundColor Green
    Write-Host "  First product: $($response.products[0].name) - `$$($response.products[0].price)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Get products failed: $_" -ForegroundColor Red
}

# Test 3: Search Products
Write-Host "`n[Test 3] Search Products" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products?search=Product%201&limit=10" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Search returned $($response.products.Count) results" -ForegroundColor Green
} catch {
    Write-Host "✗ Search products failed: $_" -ForegroundColor Red
}

# Test 4: Get Categories
Write-Host "`n[Test 4] Get Categories" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products/categories/list" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Retrieved $($response.totalCategories) categories" -ForegroundColor Green
    foreach ($cat in $response.categories) {
        Write-Host "  - $cat : $($response.statistics[$cat]) products" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ Get categories failed: $_" -ForegroundColor Red
}

# Test 5: Cart without authentication (should fail)
Write-Host "`n[Test 5] Cart without authentication (should fail)" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/cart" -UseBasicParsing -ErrorAction Stop
    Write-Host "✗ Cart allowed without auth (SECURITY ISSUE)" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✓ Cart properly requires authentication (401)" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $_" -ForegroundColor Red
    }
}

# Test 6: Cart with authentication
Write-Host "`n[Test 6] Cart with authentication" -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $testToken"
        "Content-Type" = "application/json"
    }
    $response = Invoke-RestMethod -Uri "$baseUrl/api/cart" -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Retrieved cart: $($response.cart.itemCount) items, total: `$$($response.cart.total)" -ForegroundColor Green
} catch {
    Write-Host "✗ Get cart failed: $_" -ForegroundColor Red
}

# Test 7: Add to cart
Write-Host "`n[Test 7] Add item to cart" -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $testToken"
        "Content-Type" = "application/json"
    }
    $body = @{
        productId = "1"
        quantity = 2
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/cart" -Method POST -Headers $headers -Body $body -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Added to cart: $($response.addedItem.productId) x $($response.addedItem.quantity)" -ForegroundColor Green
    Write-Host "  Cart total: `$$($response.cart.total)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Add to cart failed: $_" -ForegroundColor Red
}

# Test 8: Create Product (without auth - should fail)
Write-Host "`n[Test 8] Create product without auth (should fail)" -ForegroundColor Yellow
try {
    $body = @{
        name = "Test Product"
        price = 99.99
        category = "Electronics"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method POST -Body $body -UseBasicParsing -ErrorAction Stop
    Write-Host "✗ Product creation allowed without auth (SECURITY ISSUE)" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✓ Product creation properly requires authentication" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $_" -ForegroundColor Red
    }
}

# Test 9: Create Product (with auth)
Write-Host "`n[Test 9] Create product with authentication" -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer test-admin-token"
        "Content-Type" = "application/json"
    }
    $body = @{
        name = "New Electronics Item"
        price = 199.99
        category = "Electronics"
        brand = "TestBrand"
        stock = 50
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products" -Method POST -Headers $headers -Body $body -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Product created successfully (ID: $($response.product.id))" -ForegroundColor Green
    Write-Host "  Product: $($response.product.name) - `$$($response.product.price)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Create product failed: $_" -ForegroundColor Red
}

# Test 10: Secret endpoint with different access methods
Write-Host "`n[Test 10] Secret endpoint access methods" -ForegroundColor Yellow

# 10a: Bearer token
try {
    $headers = @{
        "Authorization" = "Bearer secret-admin-token"
    }
    $response = Invoke-RestMethod -Uri "$baseUrl/api/product_secret_endpoint" -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Access via Bearer token succeeded" -ForegroundColor Green
    Write-Host "  Access method: $($response.accessMethod)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Bearer token access failed: $_" -ForegroundColor Red
}

# 10b: API Key
try {
    $headers = @{
        "x-api-key" = "admin-api-key-2024"
    }
    $response = Invoke-RestMethod -Uri "$baseUrl/api/product_secret_endpoint" -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Access via API Key succeeded" -ForegroundColor Green
} catch {
    Write-Host "✗ API Key access failed: $_" -ForegroundColor Red
}

# 10c: Query parameter
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/product_secret_endpoint?secret=profit-data" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Access via query parameter succeeded" -ForegroundColor Green
} catch {
    Write-Host "✗ Query parameter access failed: $_" -ForegroundColor Red
}

# Test 11: Security - No data leakage
Write-Host "`n[Test 11] Security - Data Leakage Check" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products/1" -UseBasicParsing -ErrorAction Stop
    $hasInternalData = $response | Get-Member -Name "costPrice" -ErrorAction SilentlyContinue
    
    if ($hasInternalData) {
        Write-Host "✗ Internal cost data leaked! (SECURITY ISSUE)" -ForegroundColor Red
    } else {
        Write-Host "✓ No sensitive internal data exposed in product response" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Get product failed: $_" -ForegroundColor Red
}

Write-Host "`n====== Test Suite Complete ======" -ForegroundColor Green
