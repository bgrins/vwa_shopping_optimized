#!/usr/bin/env python3
"""
Check a specific product's data in the database
"""

import MySQLdb
import sys

def check_product(url_key_or_sku):
    """Check product data"""
    
    # Connect to MySQL
    conn = MySQLdb.connect(
        host='127.0.0.1',
        user='root',
        passwd='1234567890',
        db='magentodb'
    )
    
    cursor = conn.cursor()
    
    # First find the product
    cursor.execute("""
        SELECT p.entity_id, p.sku
        FROM catalog_product_entity p
        LEFT JOIN catalog_product_entity_varchar pu 
            ON p.entity_id = pu.entity_id AND pu.attribute_id = 121 AND pu.store_id = 0
        WHERE pu.value = %s OR p.sku = %s
        LIMIT 1
    """, (url_key_or_sku, url_key_or_sku))
    
    result = cursor.fetchone()
    if not result:
        print(f"Product not found: {url_key_or_sku}")
        return
    
    entity_id, sku = result
    print(f"Found product: entity_id={entity_id}, sku={sku}")
    print("-" * 60)
    
    # Get all text attributes for this product
    print("\nText attributes (descriptions):")
    cursor.execute("""
        SELECT ea.attribute_code, ea.attribute_id, pt.value, pt.store_id
        FROM catalog_product_entity_text pt
        JOIN eav_attribute ea ON ea.attribute_id = pt.attribute_id
        WHERE pt.entity_id = %s
        ORDER BY ea.attribute_id, pt.store_id
    """, (entity_id,))
    
    for row in cursor.fetchall():
        attr_code, attr_id, value, store_id = row
        value_preview = value[:100] + "..." if value and len(value) > 100 else value
        print(f"  [{attr_id}] {attr_code} (store {store_id}): {value_preview}")
    
    # Get varchar attributes
    print("\nVarchar attributes:")
    cursor.execute("""
        SELECT ea.attribute_code, ea.attribute_id, pv.value, pv.store_id
        FROM catalog_product_entity_varchar pv
        JOIN eav_attribute ea ON ea.attribute_id = pv.attribute_id
        WHERE pv.entity_id = %s AND ea.attribute_id IN (73, 121, 87, 88, 89)
        ORDER BY ea.attribute_id, pv.store_id
    """, (entity_id,))
    
    for row in cursor.fetchall():
        attr_code, attr_id, value, store_id = row
        print(f"  [{attr_id}] {attr_code} (store {store_id}): {value}")
    
    cursor.close()
    conn.close()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        # Default to the product you mentioned
        product = "3pcs-metal-eye-and-face-cream-applicator-stick-cosmetics-spoon-spatula-massager-tool-for-facial-massage-under-eye-roller-reduce-puffiness"
    else:
        product = sys.argv[1]
    
    check_product(product)