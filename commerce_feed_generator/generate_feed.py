#!/usr/bin/env python3
"""
Generate Commerce Feed from Magento 2 Database
"""

import json
import MySQLdb
import os
import time
import re
from datetime import datetime
from html.parser import HTMLParser

# Magento attribute IDs
ATTR_NAME = 73
ATTR_DESCRIPTION = 75
ATTR_SHORT_DESC = 76
ATTR_PRICE = 77
ATTR_IMAGE = 87
ATTR_URL_KEY = 121

class HTMLStripper(HTMLParser):
    """Strip HTML tags from text"""
    def __init__(self):
        super().__init__()
        self.reset()
        self.strict = False
        self.convert_charrefs = True
        self.text = []
        
    def handle_data(self, d):
        self.text.append(d)
        
    def get_data(self):
        return ' '.join(self.text)

def strip_html(html):
    """Remove HTML tags and clean up text"""
    if not html:
        return ''
    
    # Try to strip HTML tags
    s = HTMLStripper()
    s.feed(html)
    text = s.get_data()
    
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text

def wait_for_db(max_retries=30):
    """Wait for database to be available"""
    db_host = os.getenv('DB_HOST', 'mysql')
    db_pass = os.getenv('DB_PASSWORD', '')
    
    for i in range(max_retries):
        try:
            conn = MySQLdb.connect(
                host=db_host,
                user='root',
                passwd=db_pass,
                db='magentodb'
            )
            conn.close()
            print(f"Database is ready!")
            return True
        except Exception as e:
            print(f"Waiting for database... ({i+1}/{max_retries}) - {str(e)}")
            time.sleep(2)
    
    return False

def get_products():
    """Connect to database and get product data"""
    
    db_host = os.getenv('DB_HOST', 'mysql')
    db_pass = os.getenv('DB_PASSWORD', '')
    base_url = os.getenv('BASE_URL', 'https://shop.example.com')
    limit = os.getenv('LIMIT', '')  # Optional limit
    
    # Connect to MySQL
    conn = MySQLdb.connect(
        host=db_host,
        user='root',
        passwd=db_pass,
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
        ON p.entity_id = pd.entity_id AND pd.attribute_id = %s AND pd.store_id = 1
    LEFT JOIN catalog_product_entity_text psd 
        ON p.entity_id = psd.entity_id AND psd.attribute_id = %s AND psd.store_id = 1
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
    
    # Add LIMIT if specified
    if limit:
        query += f" LIMIT {int(limit)}"
    
    cursor.execute(query, (ATTR_NAME, ATTR_DESCRIPTION, ATTR_SHORT_DESC, 
                          ATTR_PRICE, ATTR_URL_KEY, ATTR_IMAGE))
    
    products = []
    for row in cursor.fetchall():
        entity_id, sku, name, description, short_desc, price, url_key, image = row
        
        # Build product feed entry
        # Strip HTML from description
        clean_description = strip_html(description or short_desc or '')
        
        product = {
            'id': sku,  # Amazon ASIN
            'title': (name or '')[:150],  # Max 150 chars
            'description': clean_description[:5000],  # Max 5000 chars, HTML stripped
            'link': f"{base_url}/{url_key}" if url_key else f"{base_url}/product/{sku}",
            'price': f"{float(price or 0):.2f} USD",
            'availability': 'in_stock',
            'enable_search': True,
            'enable_checkout': True,
            'condition': 'new'
        }
        
        # Add image if available
        if image and image != 'no_selection':
            product['images'] = [f"{base_url}/media/catalog/product{image}"]
            
        products.append(product)
    
    cursor.close()
    conn.close()
    
    return products

def main():
    """Generate and save the feed"""
    
    print("Commerce Feed Generator")
    print("=" * 40)
    
    # Wait for database
    if not wait_for_db():
        print("Error: Database not available")
        return 1
    
    print("Connecting to database...")
    products = get_products()
    
    print(f"Found {len(products)} products")
    
    # Create feed structure
    feed = {
        'products': products,
        'metadata': {
            'generated': datetime.now().isoformat(),
            'count': len(products),
            'format': 'commerce_feed_v1'
        }
    }
    
    # Save to file
    output_dir = '/output'
    os.makedirs(output_dir, exist_ok=True)
    output_filename = os.getenv('OUTPUT_FILE', 'commerce_feed.json')
    output_file = f'{output_dir}/{output_filename}'
    
    with open(output_file, 'w') as f:
        json.dump(feed, f, indent=2)
    
    print(f"Feed saved to {output_file}")
    
    # Print sample
    if products:
        print("\nSample product:")
        print(json.dumps(products[0], indent=2))
    
    return 0

if __name__ == '__main__':
    exit(main())