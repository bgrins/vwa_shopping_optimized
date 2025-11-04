#!/usr/bin/env python3
"""
Generate OpenAI Commerce Feed from Magento 2 Database
Run this inside the Docker container with database access
"""

import json
import MySQLdb
from datetime import datetime

# Magento attribute IDs
ATTR_NAME = 73
ATTR_DESCRIPTION = 75
ATTR_SHORT_DESC = 76
ATTR_PRICE = 77
ATTR_IMAGE = 87
ATTR_URL_KEY = 121

def get_products():
    """Connect to database and get product data"""
    
    # Connect to MySQL (assuming we're in the container)
    conn = MySQLdb.connect(
        host='localhost',
        user='root',
        passwd='',
        db='magentodb'
    )
    
    cursor = conn.cursor()
    
    # Query products with their attributes
    query = """
    SELECT 
        p.entity_id,
        p.sku,
        pn.value as name,
        pd.value as description,
        psd.value as short_description,
        pp.value as price,
        pu.value as url_key,
        pi.value as image
    FROM catalog_product_entity p
    LEFT JOIN catalog_product_entity_varchar pn 
        ON p.entity_id = pn.entity_id AND pn.attribute_id = %s AND pn.store_id = 0
    LEFT JOIN catalog_product_entity_text pd 
        ON p.entity_id = pd.entity_id AND pd.attribute_id = %s AND pd.store_id = 0
    LEFT JOIN catalog_product_entity_text psd 
        ON p.entity_id = psd.entity_id AND psd.attribute_id = %s AND psd.store_id = 0
    LEFT JOIN catalog_product_entity_decimal pp 
        ON p.entity_id = pp.entity_id AND pp.attribute_id = %s AND pp.store_id = 0
    LEFT JOIN catalog_product_entity_varchar pu 
        ON p.entity_id = pu.entity_id AND pu.attribute_id = %s AND pu.store_id = 0
    LEFT JOIN catalog_product_entity_varchar pi 
        ON p.entity_id = pi.entity_id AND pi.attribute_id = %s AND pi.store_id = 0
    WHERE p.type_id = 'simple'
    AND pn.value IS NOT NULL
    AND pp.value IS NOT NULL
    ORDER BY p.entity_id
    """
    
    cursor.execute(query, (ATTR_NAME, ATTR_DESCRIPTION, ATTR_SHORT_DESC, 
                          ATTR_PRICE, ATTR_URL_KEY, ATTR_IMAGE))
    
    products = []
    for row in cursor.fetchall():
        entity_id, sku, name, description, short_desc, price, url_key, image = row
        
        # Build product feed entry
        product = {
            'id': sku,  # Amazon ASIN
            'title': (name or '')[:150],  # Max 150 chars
            'description': (description or short_desc or '')[:5000],  # Max 5000 chars
            'link': f"https://shop.example.com/{url_key}" if url_key else f"https://shop.example.com/product/{sku}",
            'price': f"{float(price or 0):.2f} USD",
            'availability': 'in_stock',
            'enable_search': True,
            'enable_checkout': True,
            'condition': 'new'
        }
        
        # Add image if available
        if image and image != 'no_selection':
            product['images'] = [f"https://shop.example.com/media/catalog/product{image}"]
            
        products.append(product)
    
    cursor.close()
    conn.close()
    
    return products

def main():
    """Generate and save the feed"""
    
    print("Connecting to database...")
    products = get_products()
    
    print(f"Found {len(products)} products")
    
    # Create feed structure
    feed = {
        'products': products,
        'metadata': {
            'generated': datetime.now().isoformat(),
            'count': len(products),
            'format': 'openai_commerce_v1'
        }
    }
    
    # Save to file
    output_file = '/tmp/openai_commerce_feed.json'
    with open(output_file, 'w') as f:
        json.dump(feed, f, indent=2)
    
    print(f"Feed saved to {output_file}")
    
    # Print sample
    if products:
        print("\nSample product:")
        print(json.dumps(products[0], indent=2))

if __name__ == '__main__':
    main()