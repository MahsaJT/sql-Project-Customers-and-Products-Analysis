-- the stores database contains 8 tables
-- CUSTOMERS contains informations about customers as 12 columns
-- EMPLOYEES contains informations about employees and who they 
-- report to 
-- OFFICES have informations about country and adresses
-- ORDERDETAILS about orders and prices for each sales order
-- ORDERS abouts order and shipping date and comments
-- PAYMENTS costomers' payment orders
-- PRODUCTLINES
-- PRODUCTS has everything about products  
-- ........................................
-- QUESTIONS :
-- 1: Which products should we order more of or less of?
-- 2: How should we tailor marketing and communication strategies to customer behaviors?
-- 3: How much can we spend on acquiring new customers?


-- THE CODE BELOW SHOWS ALL THE TABLE NAMES, NUMBER OF ATTRIBUTES AND ROWS FOR EACH TABLE
SELECT 
       'Customers' AS table_name, 
       ( SELECT COUNT(*) FROM pragma_table_info('customers')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM customers
 UNION ALL
SELECT
       'Employees' AS table_name,
       (SELECT COUNT(*) FROM pragma_table_info('employees')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM employees
 UNION ALL
SELECT 
       'Offices' AS table_name, 
       ( SELECT COUNT(*) FROM pragma_table_info('offices')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM offices
 UNION ALL
SELECT
       'Orderdetails' AS table_name,
       (SELECT COUNT(*) FROM pragma_table_info('orderdetails')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM orderdetails
 UNION ALL
SELECT 
       'Orders' AS table_name, 
       ( SELECT COUNT(*) FROM pragma_table_info('orders')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM orders
 UNION ALL
SELECT
       'Payments' AS table_name,
       (SELECT COUNT(*) FROM pragma_table_info('payments')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM payments
 UNION ALL
SELECT 
       'Productlines' AS table_name, 
       ( SELECT COUNT(*) FROM pragma_table_info('productlines')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM productlines
 UNION ALL
SELECT
       'Products' AS table_name,
       (SELECT COUNT(*) FROM pragma_table_info('products')) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM products;

--compute the low stock for each product = (sum(quantityOrdered)*1.0/quantityInStock)
--compute the product performance for each product = SUM(quantityOrdered*priceEach)

WITH low_stock AS (
 SELECT P.productCode , 
        p.productName,
        p.productLine,
        ROUND(SUM(o.quantityOrdered)*1.0/P.quantityInStock , 2) AS low_stock
   FROM products AS p
   JOIN orderdetails AS o
     ON p.productCode = o.productCode
  GROUP BY p.productCode, p.productName, p.productLine

),

high_demands AS(
 SELECT productCode, 
        SUM(quantityOrdered*priceEach) AS product_performance
   FROM orderdetails
  GROUP BY productCode
)

SELECT ls.productCode,
       ls.productName AS product_name,
       ls.low_stock,
       ls.productLine
  FROM low_stock AS ls
  JOIN high_demands AS hg
    ON ls.productCode = hg.productCode
 WHERE ls.productCode IN (
                        SELECT productCode
                          FROM high_demands
                         ORDER BY product_performance DESC)
ORDER BY ls.low_stock DESC
 LIMIT 10;

-- question 2 : How should we tailor marketing and communication strategies to customer behaviors?
-- compute how much profit each customer generates
WITH customer_profits AS(
 SELECT
        o.customerNumber,
        SUM(od.quantityOrdered *(od.priceEach-p.buyPrice)) AS profit        
   FROM products AS p
   JOIN orderdetails AS od
     ON p.productCode = od.productCode
   JOIN orders AS o
     ON od.orderNumber = o.orderNumber
  GROUP BY o.customerNumber
  ORDER BY profit DESC
),
customer_engage_table AS
(SELECT c.contactLastName AS last_name,
       c.contactFirstName AS first_name,
       c.city, 
       c.country,
       cp.profit,
       CASE
  WHEN cp.profit IN (SELECT profit
                       FROM customer_profits
                       ORDER BY profit DESC
                       LIMIT 5) THEN 'Top 5 VIP Customer'
  WHEN cp.profit IN (SELECT profit
                       FROM customer_profits
                      ORDER BY profit ASC
                      LIMIT 5) THEN '5 least-engaged Customer'
  ELSE 'Regular Customers'
   END AS customer_engage
  FROM customers AS c
  JOIN customer_profits AS cp
    ON c.customerNumber = cp.customerNumber
)

SELECT last_name, first_name,city, country,profit,customer_engage
FROM customer_engage_table
WHERE customer_engage IN( 'Top 5 VIP Customer' ,'5 least-engaged Customer');


  
-- Question 3: How much can we spend on acquiring new customers?
WITH
payment_with_year_month_table AS (
SELECT *,
        CAST( SUBSTR(paymentDate, 1,4) AS INTEGER )*100 + CAST(SUBSTR(paymentDate, 6,7) AS INTEGER) AS year_month
  FROM payments AS p
),
customers_by_month_table AS(
SELECT pym.year_month, COUNT(*) AS number_of_customers, SUM(pym.amount) AS total
  FROM payment_with_year_month_table AS pym
 GROUP BY pym.year_month
),
new_customer_by_month_table AS(
SELECT pym.year_month, COUNT(DISTINCT customerNumber) AS number_of_new_customers,
       SUM(pym.amount) AS new_customer_total,
       (SELECT number_of_customers
          FROM customers_by_month_table AS cm
         WHERE cm.year_month = pym.year_month) AS number_of_customers,
       (SELECT total
          FROM customers_by_month_table AS cm
         WHERE cm.year_month = pym.year_month) AS total
  FROM payment_with_year_month_table AS pym
 WHERE pym.customerNumber NOT IN (SELECT customerNumber
                                    FROM payment_with_year_month_table AS pym2
                                   WHERE pym2.year_month < pym.year_month)
 GROUP BY pym.year_month
)
SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS number_of_new_customers_props,
       ROUND(new_customer_total*100/total,1) AS new_customers_total_props
  FROM new_customer_by_month_table;

--compute the average of customer profits
WITH customer_profits AS(
 SELECT
        o.customerNumber,
        SUM(od.quantityOrdered *(od.priceEach-p.buyPrice)) AS profit        
   FROM products AS p
   JOIN orderdetails AS od
     ON p.productCode = od.productCode
   JOIN orders AS o
     ON od.orderNumber = o.orderNumber
  GROUP BY o.customerNumber
  ORDER BY profit DESC
)
SELECT AVG(profit) AS LTV
  FROM customer_profits;
 
