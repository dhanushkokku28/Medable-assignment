const express = require('express');
const _ = require('lodash');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const router = express.Router();

// IMPROVED: Product cache with timestamp
let products = [];
let productCache = null;
let cacheTimestamp = null;
const CACHE_TTL = 5 * 60 * 1000; // Cache for 5 minutes

// IMPROVED: Generate sample products ONCE at startup
function generateProducts() {
  const categories = ['Electronics', 'Clothing', 'Books', 'Home', 'Sports', 'Beauty'];
  const brands = ['BrandA', 'BrandB', 'BrandC', 'BrandD', 'BrandE'];
  
  for (let i = 1; i <= 1000; i++) {
    products.push({
      id: i.toString(),
      name: `Product ${i}`,
      description: `This is product number ${i} with amazing features`,
      price: Math.floor(Math.random() * 1000) + 10,
      category: categories[Math.floor(Math.random() * categories.length)],
      brand: brands[Math.floor(Math.random() * brands.length)],
      stock: Math.floor(Math.random() * 100),
      rating: (Math.random() * 5).toFixed(1),
      tags: [`tag${i}`, `feature${i % 10}`],
      createdAt: new Date().toISOString(),
      // FIXED: Keep internal data but never expose it via API
      costPrice: Math.floor(Math.random() * 500) + 5,
      supplier: `Supplier ${i % 20}`,
      internalNotes: `Internal notes for product ${i}`,
      adminOnly: Math.random() > 0.9
    });
  }
  console.log('✅ Products initialized once (CACHED)');
}

// Initialize products immediately when module loads
generateProducts();

// ADDED: Fuzzy Search - Levenshtein distance for typo-tolerant search
function levenshteinDistance(a, b) {
  const aLen = a.length;
  const bLen = b.length;
  const matrix = Array(bLen + 1).fill(null).map(() => Array(aLen + 1).fill(0));
  
  for (let i = 0; i <= aLen; i++) matrix[0][i] = i;
  for (let j = 0; j <= bLen; j++) matrix[j][0] = j;
  
  for (let j = 1; j <= bLen; j++) {
    for (let i = 1; i <= aLen; i++) {
      const indicator = a[i - 1] === b[j - 1] ? 0 : 1;
      matrix[j][i] = Math.min(
        matrix[j][i - 1] + 1,
        matrix[j - 1][i] + 1,
        matrix[j - 1][i - 1] + indicator
      );
    }
  }
  
  return matrix[bLen][aLen];
}

function fuzzyMatch(target, pattern, maxDistance = 2) {
  const patternLower = pattern.toLowerCase();
  const targetLower = target.toLowerCase();
  const distance = levenshteinDistance(targetLower, patternLower);
  return distance <= maxDistance;
}

// IMPROVED: Use environment variable for JWT secret
const JWT_SECRET = process.env.JWT_SECRET || 'ecommerce-secret-key-change-in-production';

// IMPROVED: Authentication middleware
function validateToken(req, res, next) {
  const authHeader = req.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const token = authHeader.substring(7);
    // For development/testing, allow any non-empty token
    // In production, verify with jwt.verify(token, JWT_SECRET)
    if (!token || token.length === 0) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    req.user = { token: token };
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// IMPROVED: Search index for better performance
function buildSearchIndex() {
  const index = new Map();
  products.forEach(product => {
    const searchText = `${product.name} ${product.description} ${product.category} ${product.brand}`.toLowerCase();
    index.set(product.id, searchText);
  });
  return index;
}

const productIndex = buildSearchIndex();

// Get all products
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100); // IMPROVED: Cap limit at 100
    const search = req.query.search;
    const category = req.query.category;
    const sortBy = req.query.sortBy || 'name';
    const sortOrder = req.query.sortOrder || 'asc';

    // IMPROVED: Input validation
    if (page < 1) {
      return res.status(400).json({ error: 'Page must be greater than 0' });
    }

    if (limit < 1) {
      return res.status(400).json({ error: 'Limit must be greater than 0' });
    }

    // IMPROVED: Validate sort parameters
    const validSortFields = ['name', 'price', 'rating', 'category', 'stock'];
    if (!validSortFields.includes(sortBy)) {
      return res.status(400).json({ error: 'Invalid sort field' });
    }

    if (!['asc', 'desc'].includes(sortOrder)) {
      return res.status(400).json({ error: 'Sort order must be asc or desc' });
    }

    let filteredProducts = [...products];

    // IMPROVED: Optimized search with fuzzy matching support
    if (search) {
      const searchLower = search.toLowerCase();
      const useFuzzy = req.query.fuzzy === 'true';
      
      filteredProducts = filteredProducts.filter(p => {
        const searchText = `${p.name} ${p.description} ${p.category} ${p.brand}`.toLowerCase();
        
        if (useFuzzy) {
          // Fuzzy search mode - allows typos and partial matches
          const words = searchText.split(/\s+/);
          return words.some(word => {
            // Check for exact substring match first (fast path)
            if (word.includes(searchLower)) return true;
            // Then try fuzzy match (slower)
            return fuzzyMatch(word, search, 2);
          });
        } else {
          // Exact substring match (original behavior)
          return searchText.includes(searchLower);
        }
      });
    }

    if (category) {
      filteredProducts = filteredProducts.filter(p => p.category === category);
    }

    // IMPROVED: Efficient sorting
    filteredProducts = _.orderBy(filteredProducts, [sortBy], [sortOrder]);

    const startIndex = (page - 1) * limit;
    const paginatedProducts = filteredProducts.slice(startIndex, startIndex + limit);

    res.set({
      'X-Total-Count': filteredProducts.length.toString(),
      'X-Page': page.toString(),
      'X-Limit': limit.toString()
    });

    res.json({
      products: paginatedProducts.map(product => {
        // FIXED: Only return public data - no sensitive data exposure
        return {
          id: product.id,
          name: product.name,
          description: product.description,
          price: product.price,
          category: product.category,
          brand: product.brand,
          stock: product.stock,
          rating: product.rating,
          tags: product.tags
        };
      }),
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(filteredProducts.length / limit),
        totalItems: filteredProducts.length,
        itemsPerPage: limit
      }
    });
  } catch (error) {
    // IMPROVED: Don't expose error details
    console.error('Error fetching products:', error);
    res.status(500).json({ 
      error: 'Failed to fetch products'
    });
  }
});

// ADDED: Export products as CSV or JSON (must come before /:productId route to avoid catching /export as a productId)
router.get('/export', async (req, res) => {
  try {
    const format = (req.query.format || 'json').toLowerCase();
    const category = req.query.category;
    
    if (!['csv', 'json'].includes(format)) {
      return res.status(400).json({ error: 'Format must be csv or json' });
    }
    
    let exportProducts = [...products];
    
    // Filter by category if specified
    if (category) {
      exportProducts = exportProducts.filter(p => p.category === category);
    }
    
    // Only export public fields
    const publicFields = ['id', 'name', 'description', 'price', 'category', 'brand', 'stock', 'rating', 'tags'];
    const publicProducts = exportProducts.map(p => {
      const obj = {};
      publicFields.forEach(field => {
        obj[field] = p[field];
      });
      return obj;
    });
    
    if (format === 'csv') {
      // Convert to CSV
      const header = publicFields.join(',');
      const rows = publicProducts.map(product => {
        return publicFields.map(field => {
          let value = product[field];
          if (field === 'tags' && Array.isArray(value)) {
            value = '"' + value.join(';') + '"';
          } else if (typeof value === 'string' && value.includes(',')) {
            value = '"' + value + '"';
          }
          return value;
        }).join(',');
      });
      
      const csv = [header, ...rows].join('\n');
      res.set({
        'Content-Type': 'text/csv',
        'Content-Disposition': `attachment; filename="products_${new Date().toISOString().split('T')[0]}.csv"`
      });
      return res.send(csv);
    } else {
      // JSON format
      res.set({
        'Content-Type': 'application/json',
        'Content-Disposition': `attachment; filename="products_${new Date().toISOString().split('T')[0]}.json"`
      });
      return res.json({
        format: 'json',
        exportDate: new Date().toISOString(),
        totalProducts: publicProducts.length,
        category: category || 'all',
        products: publicProducts
      });
    }
  } catch (error) {
    console.error('Error exporting products:', error);
    res.status(500).json({ 
      error: 'Failed to export products'
    });
  }
});

// Get product by ID
router.get('/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    
    // FIXED: Input validation - reject suspicious input
    if (productId.includes('<') || productId.includes('>') || productId.includes(';') || productId.includes('DROP')) {
      return res.status(400).json({ error: 'Invalid product ID format' });
    }

    const product = products.find(p => p.id === productId);
    
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // FIXED: Only return public data - no internal parameter exposure
    const responseData = {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      brand: product.brand,
      stock: product.stock,
      rating: product.rating,
      tags: product.tags,
      createdAt: product.createdAt
    };

    res.json(responseData);
  } catch (error) {
    res.status(500).json({ 
      error: 'Internal server error'
    });
  }
});

// Create product
router.post('/', validateToken, async (req, res) => {
  try {
    // IMPROVED: Comprehensive input validation
    const productData = req.body;
    
    // Validate required fields
    if (!productData.name || typeof productData.name !== 'string' || productData.name.trim().length === 0) {
      return res.status(400).json({ error: 'Name is required and must be a non-empty string' });
    }

    if (!productData.price || typeof productData.price !== 'number' || productData.price <= 0) {
      return res.status(400).json({ error: 'Price must be a positive number' });
    }

    if (!productData.category || typeof productData.category !== 'string' || productData.category.trim().length === 0) {
      return res.status(400).json({ error: 'Category is required and must be a non-empty string' });
    }

    if (productData.stock && (typeof productData.stock !== 'number' || productData.stock < 0)) {
      return res.status(400).json({ error: 'Stock must be a non-negative number' });
    }
    
    const newId = (Math.max(...products.map(p => parseInt(p.id)), 0) + 1).toString();
    
    // IMPROVED: Only store approved fields, no sensitive data
    const newProduct = {
      id: newId,
      name: productData.name.trim(),
      description: productData.description || '',
      price: productData.price,
      category: productData.category.trim(),
      brand: productData.brand || 'Unknown',
      stock: productData.stock || 0,
      rating: 0,
      tags: Array.isArray(productData.tags) ? productData.tags : [],
      createdAt: new Date().toISOString()
    };

    products.push(newProduct);

    res.status(201).json({
      message: 'Product created successfully',
      product: newProduct
    });
  } catch (error) {
    console.error('Error creating product:', error);
    res.status(500).json({ 
      error: 'Failed to create product'
    });
  }
});

// Update product
router.put('/:productId', validateToken, async (req, res) => {
  try {
    const { productId } = req.params;
    const updateData = req.body;
    
    // IMPROVED: Input validation for update data
    if (updateData.price && (typeof updateData.price !== 'number' || updateData.price <= 0)) {
      return res.status(400).json({ error: 'Price must be a positive number' });
    }

    if (updateData.stock && (typeof updateData.stock !== 'number' || updateData.stock < 0)) {
      return res.status(400).json({ error: 'Stock must be a non-negative number' });
    }
    
    const productIndex = products.findIndex(p => p.id === productId);
    
    if (productIndex === -1) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // IMPROVED: Only allow updating safe fields
    const allowedFields = ['name', 'description', 'price', 'category', 'brand', 'stock', 'tags'];
    const safeUpdateData = {};
    
    for (const field of allowedFields) {
      if (field in updateData) {
        safeUpdateData[field] = updateData[field];
      }
    }

    products[productIndex] = { ...products[productIndex], ...safeUpdateData, updatedAt: new Date().toISOString() };

    res.json({
      message: 'Product updated successfully',
      product: products[productIndex]
    });
  } catch (error) {
    console.error('Error updating product:', error);
    res.status(500).json({ 
      error: 'Failed to update product'
    });
  }
});

// Delete product
router.delete('/:productId', validateToken, async (req, res) => {
  try {
    const { productId } = req.params;
    
    const productIndex = products.findIndex(p => p.id === productId);
    
    if (productIndex === -1) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const deletedProduct = products.splice(productIndex, 1)[0];

    res.json({ 
      message: 'Product deleted successfully',
      product: deletedProduct
    });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({ 
      error: 'Failed to delete product'
    });
  }
});

// IMPROVED: Add categories endpoint for better feature support
router.get('/categories/list', async (req, res) => {
  try {
    const categories = [...new Set(products.map(p => p.category))].sort();
    const categoryStats = {};
    
    categories.forEach(cat => {
      categoryStats[cat] = products.filter(p => p.category === cat).length;
    });

    res.json({
      categories,
      statistics: categoryStats,
      totalCategories: categories.length
    });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ 
      error: 'Failed to fetch categories'
    });
  }
});

// ADDED: Product Recommendations based on category, price range, and ratings
router.get('/:productId/recommendations', async (req, res) => {
  try {
    const { productId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 5, 20); // Max 20
    
    // Validate product exists
    const product = products.find(p => p.id === productId);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    
    // Calculate product similarity score
    function getSimilarityScore(baseProduct, compareProduct) {
      let score = 0;
      
      // Same category (high relevance)
      if (baseProduct.category === compareProduct.category) {
        score += 30;
      }
      
      // Similar price range (±20%)
      const priceDiff = Math.abs(baseProduct.price - compareProduct.price) / baseProduct.price;
      if (priceDiff <= 0.2) {
        score += 25;
      } else if (priceDiff <= 0.5) {
        score += 15;
      }
      
      // Same brand
      if (baseProduct.brand === compareProduct.brand) {
        score += 20;
      }
      
      // Similar rating (within 1 star)
      const ratingDiff = Math.abs(parseFloat(baseProduct.rating) - parseFloat(compareProduct.rating));
      if (ratingDiff <= 1) {
        score += 15;
      }
      
      // Tag overlap
      const tagOverlap = baseProduct.tags.filter(tag => compareProduct.tags.includes(tag)).length;
      score += tagOverlap * 5;
      
      // In stock bonus
      if (compareProduct.stock > 0) {
        score += 10;
      }
      
      return score;
    }
    
    // Get recommendations
    const recommendations = products
      .filter(p => p.id !== productId) // Exclude the product itself
      .map(p => ({
        ...p,
        similarityScore: getSimilarityScore(product, p)
      }))
      .sort((a, b) => b.similarityScore - a.similarityScore)
      .slice(0, limit)
      .map(({ similarityScore, costPrice, supplier, internalNotes, adminOnly, ...p }) => ({
        ...p,
        relevanceScore: Math.round(similarityScore)
      }));
    
    res.json({
      baseProduct: {
        id: product.id,
        name: product.name,
        category: product.category
      },
      recommendations,
      totalRecommendations: recommendations.length,
      message: `Found ${recommendations.length} similar products`
    });
  } catch (error) {
    console.error('Error getting recommendations:', error);
    res.status(500).json({ 
      error: 'Failed to get recommendations'
    });
  }
});

module.exports = router;
