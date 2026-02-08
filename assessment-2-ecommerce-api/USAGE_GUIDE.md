# E-Commerce API - Usage Guide & Testing Examples

## Quick Start

### 1. Installation & Running
```bash
npm install
npm start
# Server runs on http://localhost:3002
```

### 2. Testing
```bash
powershell -ExecutionPolicy Bypass -File simple-test.ps1
```

---

## API Usage Examples

### 1. Public Endpoints (No Authentication)

#### Get Products
```bash
# Basic request - get first page
curl "http://localhost:3002/api/products"

# With pagination
curl "http://localhost:3002/api/products?page=2&limit=20"

# Search for products
curl "http://localhost:3002/api/products?search=electronics&limit=10"

# Filter by category
curl "http://localhost:3002/api/products?category=Electronics&limit=5"

# Sort results
curl "http://localhost:3002/api/products?sortBy=price&sortOrder=desc&limit=10"
```

#### Get Single Product
```bash
curl "http://localhost:3002/api/products/1"
```

Response Example:
```json
{
  "id": "1",
  "name": "Product 1",
  "description": "This is product number 1 with amazing features",
  "price": 450,
  "category": "Electronics",
  "brand": "BrandC",
  "stock": 42,
  "rating": "3.2",
  "tags": ["tag1", "feature1"]
}
```

#### List Categories
```bash
curl "http://localhost:3002/api/products/categories/list"
```

Response Example:
```json
{
  "categories": ["Beauty", "Books", "Clothing", "Electronics", "Home", "Sports"],
  "statistics": {
    "Beauty": 167,
    "Books": 180,
    "Clothing": 176,
    "Electronics": 190,
    "Home": 154,
    "Sports": 133
  },
  "totalCategories": 6
}
```

#### Health Check
```bash
curl "http://localhost:3002/health"

# Response
{
  "status": "OK",
  "timestamp": "2026-02-06T15:37:30.670Z"
}
```

---

### 2. Protected Endpoints (Require Authentication)

#### Cart Operations
All cart endpoints require: `Authorization: Bearer <token>`

**Get Cart**
```bash
curl -H "Authorization: Bearer user-token-123" \
     "http://localhost:3002/api/cart"
```

Response Example:
```json
{
  "cart": {
    "items": [
      {
        "productId": "1",
        "quantity": 2,
        "addedAt": "2026-02-06T15:40:00.000Z",
        "price": 100
      }
    ],
    "total": 200,
    "createdAt": "2026-02-06T15:40:00.000Z"
  },
  "metadata": {
    "lastUpdated": "2026-02-06T15:40:05.000Z",
    "itemCount": 1,
    "userId": "a1b2c3d4"
  }
}
```

**Add to Cart**
```bash
curl -X POST "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer user-token-123" \
  -H "Content-Type: application/json" \
  -d '{"productId":"1","quantity":2}'
```

**Batch Add to Cart**
```bash
curl -X POST "http://localhost:3002/api/cart/batch/add" \
  -H "Authorization: Bearer user-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"productId":"1","quantity":2},
      {"productId":"2","quantity":1},
      {"productId":"3","quantity":3}
    ]
  }'
```

**Update Cart Item**
```bash
# Update quantity
curl -X PUT "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer user-token-123" \
  -H "Content-Type: application/json" \
  -d '{"productId":"1","quantity":5}'

# Remove item (quantity 0)
curl -X PUT "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer user-token-123" \
  -H "Content-Type: application/json" \
  -d '{"productId":"1","quantity":0}'
```

**Batch Update Cart Items**
```bash
curl -X PUT "http://localhost:3002/api/cart/batch/update" \
  -H "Authorization: Bearer user-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [
      {"productId":"1","quantity":3},
      {"productId":"2","quantity":0}
    ]
  }'
```

**Remove from Cart**
```bash
curl -X DELETE "http://localhost:3002/api/cart?productId=1" \
  -H "Authorization: Bearer user-token-123"
```

**Clear Cart**
```bash
curl -X DELETE "http://localhost:3002/api/cart/clear/all" \
  -H "Authorization: Bearer user-token-123"
```

---

### 3. Admin/Product Management (Require Authentication)

**Create Product**
```bash
curl -X POST "http://localhost:3002/api/products" \
  -H "Authorization: Bearer admin-token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "New Electronics Item",
    "price": 299.99,
    "category": "Electronics",
    "brand": "NewBrand",
    "stock": 50,
    "description": "An excellent new product",
    "tags": ["new", "featured"]
  }'
```

**Update Product**
```bash
curl -X PUT "http://localhost:3002/api/products/1" \
  -H "Authorization: Bearer admin-token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Product Name",
    "price": 149.99,
    "stock": 25
  }'
```

**Delete Product**
```bash
curl -X DELETE "http://localhost:3002/api/products/1" \
  -H "Authorization: Bearer admin-token"
```

---

## Puzzle Solutions 🧩

### Puzzle 1: Base64 Decoder

The server response headers contain:
```
X-Puzzle-Hint: cHJvZHVjdF9zZWNyZXRfZW5kcG9pbnQ=
```

**Decode it:**
```bash
# Using Linux/Mac
echo "cHJvZHVjdF9zZWNyZXRfZW5kcG9pbnQ=" | base64 -d
# Output: product_secret_endpoint

# Using PowerShell
[System.Convert]::FromBase64String("cHJvZHVjdF9zZWNyZXRfZW5kcG9pbnQ=") | ForEach-Object { [System.Text.Encoding]::UTF8.GetString($_) }
```

**Result:** `product_secret_endpoint`

This reveals the hidden endpoint!

---

### Puzzle 2: Secret Product Endpoint

Access the secret endpoint using any of these methods:

**Method 1: Bearer Token**
```bash
curl -H "Authorization: Bearer secret-admin-token" \
     "http://localhost:3002/api/product_secret_endpoint"
```

**Method 2: API Key Header**
```bash
curl -H "x-api-key: admin-api-key-2024" \
     "http://localhost:3002/api/product_secret_endpoint"
```

**Method 3: Query Parameter**
```bash
curl "http://localhost:3002/api/product_secret_endpoint?secret=profit-data"
```

**Response Example:**
```json
{
  "message": "Secret product profit data accessed",
  "accessMethod": "bearer-token",
  "secretProducts": [
    {
      "id": "secret-1",
      "name": "Premium Exclusive Item",
      "actualCost": 50,
      "sellingPrice": 200,
      "profitMargin": "75%",
      "secretCategory": "high-margin"
    }
  ],
  "totalProfit": 148,
  "analytics": {
    "averageProfitMargin": "74%",
    "topPerformingCategory": "high-margin",
    "accessTimestamp": "2026-02-06T15:42:00.000Z"
  },
  "finalPuzzle": "Pbatenghyngvbaf! Lbh sbhaq gur frperg cebqhpg qngn. Svany pyhrf: PURPX_NQZVA_CNARY_2024",
  "puzzleHint": "Decode this message using ROT13 cipher"
}
```

---

### Puzzle 3: ROT13 Cipher Decoder

The response contains:
```
Pbatenghyngvbaf! Lbh sbhaq gur frperg cebqhpg qngn. Svany pyhrf: PURPX_NQZVA_CNARY_2024
```

**Decode using online ROT13 decoder or:**
```python
# Python
import codecs
encoded = "Pbatenghyngvbaf! Lbh sbhaq gur frperg cebqhpg qngn. Svany pyhrf: PURPX_NQZVA_CNARY_2024"
decoded = codecs.encode(encoded, 'rot_13')
print(decoded)
```

**Result:** 
```
Congratulations! You found the secret product data. Final clues: CHECK_ADMIN_PANEL_2024
```

---

### Puzzle 4: Hash Challenge

The secret endpoint response includes:
```
X-Profit-Hash: a1b2c3d4
```

This header contains a time-based MD5 hash of the current date (YYYY-MM-DD format).

**Generate it:**
```bash
# Get current date
date +"%Y-%m-%d"

# Create MD5 hash (first 8 characters)
echo -n "2026-02-06" | md5sum
```

This hash changes daily and can be used for:
- Cache invalidation strategies
- Time-based access control
- Verification of secret access rights

---

## Error Handling Examples

### Missing Authentication
```bash
curl "http://localhost:3002/api/cart"

# Response (401)
{
  "error": "Authentication required"
}
```

### Invalid Product ID
```bash
curl -X POST "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{"productId":"999","quantity":1}'

# Response (400)
{
  "error": "Invalid product ID"
}
```

### Invalid Input (Non-numeric quantity)
```bash
curl -X POST "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer token" \
  -H "Content-Type: application/json" \
  -d '{"productId":"1","quantity":"abc"}'

# Response (400)
{
  "error": "Quantity must be between 1 and 99"
}
```

### Product Not Found
```bash
curl "http://localhost:3002/api/products/99999"

# Response (404)
{
  "error": "Product not found"
}
```

---

## Security Features Verified ✅

### 1. No Data Leakage
```bash
# Try to access internal data - NOT RETURNED
curl "http://localhost:3002/api/products/1?internal=yes"

# Response only includes public fields:
# - id, name, description, price, category, brand, stock, rating, tags
# NOT INCLUDED: costPrice, supplier, internalNotes, adminOnly
```

### 2. No Admin Parameter Exposure
```bash
# Trying to access admin data - IGNORED
curl "http://localhost:3002/api/products?admin=true"

# Returns normal filtered results without admin data
```

### 3. User Isolation in Carts
```bash
# User 1 creates token and adds items
curl -X POST "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer user1-token" \
  -H "Content-Type: application/json" \
  -d '{"productId":"1","quantity":1}'

# User 2 with different token has separate cart
curl -X POST "http://localhost:3002/api/cart" \
  -H "Authorization: Bearer user2-token" \
  -H "Content-Type: application/json" \
  -d '{"productId":"2","quantity":2}'

# Each user only sees their own cart
```

---

## Performance Notes

### Product Caching Benefits
- 1000 products cached at startup
- ~0ms latency for product retrieval
- No regeneration on each request

### Cart Operations
- O(1) cart total lookup (cached)
- O(n) item search (n=items in cart, typically small)
- Batch operations: O(20) maximum items per operation

### Search Performance
- Filtered string concatenation search
- Regex-based validation  
- Linear search through filtered set (efficient given small result sets)

---

## Testing Checklist

- ✅ Public APIs accessible without authentication
- ✅ Protected APIs require valid authentication
- ✅ Cart isolated per user
- ✅ Product creation/update/delete protected
- ✅ Input validation on all endpoints
- ✅ Error messages don't leak sensitive info
- ✅ Secret endpoint accessible via all 3 methods
- ✅ Puzzle hints decodable
- ✅ No internal data exposed in responses
- ✅ Proper HTTP status codes returned

---

**Assignment Complete!** 🎉
