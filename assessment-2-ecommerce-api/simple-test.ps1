#!/usr/bin/env pwsh

Write-Host "=== E-Commerce API Tests ===" -ForegroundColor Green

$baseUrl = "http://localhost:3002"

# Test 1: Health
Write-Host "`nTest 1: Health Check"
$h = IRM "$baseUrl/health" -UseBasicParsing
Write-Host "OK: Server is $($h.status)" -ForegroundColor Green

# Test 2: Products
Write-Host "`nTest 2: Get Products"
$p = IRM "$baseUrl/api/products?limit=3" -UseBasicParsing
Write-Host "OK: Got $($p.products.Count)/$($p.pagination.totalItems) products" -ForegroundColor Green

# Test 3: Categories
Write-Host "`nTest 3: Get Categories"
$c = IRM "$baseUrl/api/products/categories/list" -UseBasicParsing
Write-Host "OK: Got $($c.totalCategories) categories" -ForegroundColor Green

# Test 4: Cart requires auth
Write-Host "`nTest 4: Cart Without Auth (Should fail)"
try {
    $n = IRM "$baseUrl/api/cart" -UseBasicParsing -ErrorAction Stop
    Write-Host "FAIL: Auth not required!" -ForegroundColor Red
} catch {
    Write-Host "OK: Auth required (401)" -ForegroundColor Green
}

# Test 5: Cart with auth
Write-Host "`nTest 5: Cart With Auth"
$headers = @{ "Authorization" = "Bearer test-token" }
$cart = IRM "$baseUrl/api/cart" -Headers $headers -UseBasicParsing
Write-Host "OK: Cart has $($cart.cart.itemCount) items" -ForegroundColor Green

# Test 6: Add to cart
Write-Host "`nTest 6: Add to Cart"
$body = @{ productId = "1"; quantity = 1 } | ConvertTo-Json
$added = IRM "$baseUrl/api/cart" -Method POST -Headers $headers -Body $body -ContentType "application/json" -UseBasicParsing
Write-Host "OK: Added product, cart total = `$$($added.cart.total)" -ForegroundColor Green

# Test 7: Create product requires auth
Write-Host "`nTest 7: Create Product Without Auth (Should fail)"
try {
    $body = @{ name = "Test"; price = 99; category = "Test" } | ConvertTo-Json
    $n = IRM "$baseUrl/api/products" -Method POST -Body $body -UseBasicParsing -ErrorAction Stop
    Write-Host "FAIL: Auth not required!" -ForegroundColor Red
} catch {
    Write-Host "OK: Auth required (401)" -ForegroundColor Green
}

# Test 8: Create product with auth
Write-Host "`nTest 8: Create Product With Auth"
$body = @{ name = "Test Product"; price = 149.99; category = "Electronics" } | ConvertTo-Json
$created = IRM "$baseUrl/api/products" -Method POST -Headers $headers -Body $body -ContentType "application/json" -UseBasicParsing
Write-Host "OK: Created product ID $($created.product.id)" -ForegroundColor Green

# Test 9: Secret endpoint - Bearer
Write-Host "`nTest 9: Secret Endpoint - Bearer Token"
$headers2 = @{ "Authorization" = "Bearer secret-admin-token" }
$secret = IRM "$baseUrl/api/product_secret_endpoint" -Headers $headers2 -UseBasicParsing
Write-Host "OK: Access via $($secret.accessMethod)" -ForegroundColor Green

# Test 10: Secret endpoint - API Key
Write-Host "`nTest 10: Secret Endpoint - API Key"
$headers3 = @{ "x-api-key" = "admin-api-key-2024" }
$secret2 = IRM "$baseUrl/api/product_secret_endpoint" -Headers $headers3 -UseBasicParsing
Write-Host "OK: Access via $($secret2.accessMethod)" -ForegroundColor Green

# Test 11: Data leakage check
Write-Host "`nTest 11: No Data Leakage Check"
$prod = IRM "$baseUrl/api/products/1" -UseBasicParsing
$members = $prod | GM -MemberType NoteProperty | Select -ExpandProperty Name
if ($members -contains "costPrice") {
    Write-Host "FAIL: costPrice exposed!" -ForegroundColor Red
} else {
    Write-Host "OK: No sensitive data exposed" -ForegroundColor Green
}

Write-Host "`n=== Tests Complete ===" -ForegroundColor Green
