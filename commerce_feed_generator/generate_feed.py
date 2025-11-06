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

def get_db_connection():
    """Get database connection"""
    db_host = os.getenv('DB_HOST', 'mysql')
    db_pass = os.getenv('DB_PASSWORD', '')

    return MySQLdb.connect(
        host=db_host,
        user='root',
        passwd=db_pass,
        db='magentodb'
    )

def get_categories():
    """Get all active categories"""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Get categories with names
    cursor.execute("""
        SELECT DISTINCT c.entity_id, cv.value as name
        FROM catalog_category_entity c
        LEFT JOIN catalog_category_entity_varchar cv
            ON c.entity_id = cv.entity_id AND cv.attribute_id = 45 AND cv.store_id = 0
        WHERE c.entity_id > 2
        AND cv.value IS NOT NULL
        ORDER BY c.entity_id
    """)

    categories = {}
    for row in cursor.fetchall():
        category_id, name = row
        if name:
            # Sanitize category name for filename
            safe_name = re.sub(r'[^\w\s-]', '', name).strip().lower()
            safe_name = re.sub(r'[-\s]+', '-', safe_name)
            categories[category_id] = {
                'id': category_id,
                'name': name,
                'filename': safe_name
            }

    cursor.close()
    conn.close()

    return categories

def get_products_by_category(category_id):
    """Get products for a specific category"""

    db_host = os.getenv('DB_HOST', 'mysql')
    db_pass = os.getenv('DB_PASSWORD', '')
    base_url = os.getenv('BASE_URL', 'https://shop.example.com')
    limit = os.getenv('LIMIT', '')  # Optional limit

    conn = get_db_connection()
    cursor = conn.cursor()

    # Query products with their attributes for specific category
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
    INNER JOIN catalog_category_product ccp ON p.entity_id = ccp.product_id
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
    AND ccp.category_id = %s
    AND pn.value IS NOT NULL
    AND pp.value IS NOT NULL
    ORDER BY p.entity_id
    """

    # Add LIMIT if specified
    if limit:
        query += f" LIMIT {int(limit)}"

    cursor.execute(query, (ATTR_NAME, ATTR_DESCRIPTION, ATTR_SHORT_DESC,
                          ATTR_PRICE, ATTR_URL_KEY, ATTR_IMAGE, category_id))

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

    print("Commerce Feed Generator (Category-based)")
    print("=" * 40)

    # Wait for database
    if not wait_for_db():
        print("Error: Database not available")
        return 1

    print("Fetching categories...")
    categories = get_categories()

    print(f"Found {len(categories)} categories")

    # Create output directories
    output_dir = '/output'
    categories_dir = f'{output_dir}/categories'
    os.makedirs(categories_dir, exist_ok=True)

    # Generate feed for each category
    total_products = 0
    category_summary = []

    for cat_id, cat_info in categories.items():
        print(f"\nProcessing category: {cat_info['name']} (ID: {cat_id})")
        products = get_products_by_category(cat_id)

        if not products:
            print(f"  No products found, skipping...")
            continue

        print(f"  Found {len(products)} products")
        total_products += len(products)

        # Create feed structure
        feed = {
            'category': {
                'id': cat_id,
                'name': cat_info['name']
            },
            'products': products,
            'metadata': {
                'generated': datetime.now().isoformat(),
                'count': len(products),
                'format': 'commerce_feed_v1'
            }
        }

        # Save to category-specific file
        output_file = f"{categories_dir}/{cat_info['filename']}.json"
        with open(output_file, 'w') as f:
            json.dump(feed, f, indent=2)

        print(f"  Saved to {output_file}")

        category_summary.append({
            'id': cat_id,
            'name': cat_info['name'],
            'filename': f"categories/{cat_info['filename']}.json",
            'product_count': len(products)
        })

    # Create index file
    index = {
        'categories': category_summary,
        'metadata': {
            'generated': datetime.now().isoformat(),
            'total_categories': len(category_summary),
            'total_products': total_products,
            'format': 'commerce_feed_v1'
        }
    }

    index_file = f'{output_dir}/index.json'
    with open(index_file, 'w') as f:
        json.dump(index, f, indent=2)

    print("\n" + "=" * 40)
    print(f"Feed generation complete!")
    print(f"Total categories: {len(category_summary)}")
    print(f"Total products: {total_products}")
    print(f"Index saved to: {index_file}")
    print(f"Category feeds in: {categories_dir}/")

    return 0

if __name__ == '__main__':
    exit(main())