-- ==============================================================================
-- PHASE 1: ENVIRONMENT SETUP
-- ==============================================================================
-- Enable local file loading for bulk CSV ingestion
SET GLOBAL local_infile = 1;

-- ==============================================================================
-- PHASE 2: SCHEMA CREATION & BULK INGESTION
-- ==============================================================================
CREATE DATABASE olist_ecommerce;
USE olist_ecommerce;

-- 1. Customers
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix VARCHAR(10) NOT NULL, -- Kept as VARCHAR to preserve leading zeros
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

-- 2. Sellers
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10) NOT NULL,
    seller_city VARCHAR(100),
    seller_state VARCHAR(5)
);

-- 3. Geolocation (Note: No single Primary Key as zip codes repeat with different lat/long coords)
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10) NOT NULL,
    geolocation_lat DECIMAL(15, 10),
    geolocation_lng DECIMAL(15, 10),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5)
);

-- 4. Products
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

-- 5. Product Category Name Translation
CREATE TABLE category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

-- 6. Orders
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

-- 7. Order Items (Composite Primary Key)
CREATE TABLE order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME,
    price DECIMAL(10, 2),
    freight_value DECIMAL(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 8. Order Payments (Composite Primary Key)
CREATE TABLE order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- 9. Order Reviews
CREATE TABLE order_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    review_score INT,
    review_comment_title VARCHAR(255),
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    -- A single review can apply to multiple orders, and an order can have multiple reviews, 
    -- so we don't enforce a strict single-column PK here to avoid import errors from duplicates.
    PRIMARY KEY (review_id, order_id) 
);

-- Load CSV files on the client into the corresponding tables
-- 1. Customers
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 2. Sellers
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 3. Geolocation
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 4. Category Translation
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/product_category_name_translation.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 5. Products (Handling blank measurements and categories)
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(product_id, @product_category_name, @product_name_lenght, @product_description_lenght, @product_photos_qty, @product_weight_g, @product_length_cm, @product_height_cm, @product_width_cm)
SET 
    product_category_name = NULLIF(@product_category_name, ''),
    product_name_lenght = NULLIF(@product_name_lenght, ''),
    product_description_lenght = NULLIF(@product_description_lenght, ''),
    product_photos_qty = NULLIF(@product_photos_qty, ''),
    product_weight_g = NULLIF(@product_weight_g, ''),
    product_length_cm = NULLIF(@product_length_cm, ''),
    product_height_cm = NULLIF(@product_height_cm, ''),
    product_width_cm = NULLIF(@product_width_cm, '');

-- 6. Orders (Handling missing timestamps)
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS
(order_id, customer_id, order_status, @order_purchase_timestamp, @order_approved_at, @order_delivered_carrier_date, @order_delivered_customer_date, @order_estimated_delivery_date)
SET 
    order_purchase_timestamp = NULLIF(@order_purchase_timestamp, ''),
    order_approved_at = NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date = NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@order_delivered_customer_date, ''),
    order_estimated_delivery_date = NULLIF(@order_estimated_delivery_date, '');

-- 7. Order Items
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 8. Order Payments
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- 9. Order Reviews (Handling blank review text and missing timestamps)
LOAD DATA LOCAL INFILE 'C:/Users/soetk/Desktop/Olist/raw_data/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS
(review_id, order_id, review_score, @review_comment_title, @review_comment_message, review_creation_date, @review_answer_timestamp)
SET 
    review_comment_title = NULLIF(@review_comment_title, ''),
    review_comment_message = NULLIF(@review_comment_message, ''),
    -- Strip out the hidden carriage return before evaluating for NULL
    review_answer_timestamp = NULLIF(REPLACE(@review_answer_timestamp, '\r', ''), '');

-- ==============================================================================
-- PHASE 3: DATA CLEANING & ANOMALY HANDLING
-- ==============================================================================
-- Row 77917 in order_reviews contains an unescaped character resulting in an invalid date. 
-- Temporarily bypassing strict modes to purge this corrupted record.
SET SESSION sql_mode = '';
SET SQL_SAFE_UPDATES = 0;

DELETE FROM order_reviews 
WHERE review_creation_date = '0000-00-00 00:00:00';

SET SQL_SAFE_UPDATES = 1;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ==============================================================================
-- PHASE 4: ESTABLISH RELATIONSHIPS (FOREIGN KEYS)
-- ==============================================================================
-- Link Orders to Customers
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

-- Link Order Items to Orders, Products, and Sellers
ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id),
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id) REFERENCES products(product_id),
ADD CONSTRAINT fk_order_items_sellers
FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);

-- Link Order Payments to Orders
ALTER TABLE order_payments
ADD CONSTRAINT fk_order_payments_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- Link Order Reviews to Orders
ALTER TABLE order_reviews
ADD CONSTRAINT fk_order_reviews_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- Insert the missing categories into the translation table.
-- We will just use the Portuguese name as the English placeholder so the link works.
INSERT INTO category_translation (product_category_name, product_category_name_english)
SELECT DISTINCT p.product_category_name, p.product_category_name
FROM products p
	LEFT JOIN category_translation c 
		ON p.product_category_name = c.product_category_name
WHERE
	c.product_category_name IS NULL 
	AND p.product_category_name IS NOT NULL;

-- Link Products to Category Translation
ALTER TABLE products
ADD CONSTRAINT fk_products_translation
FOREIGN KEY (product_category_name) REFERENCES category_translation(product_category_name);

-- ==============================================================================
-- PHASE 5: SECURITY TEARDOWN
-- ==============================================================================
-- Disable local file loading to secure the database post-ingestion
SET GLOBAL local_infile = 0;