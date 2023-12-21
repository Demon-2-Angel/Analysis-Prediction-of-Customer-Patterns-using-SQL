/*
Customers: customer data
Employees: all employee information
Offices: sales office information
Orders: customers' sales orders
OrderDetails: sales order line for each sales order
Payments: customers' payment records
Products: a list of scale model cars
ProductLines: a list of product line categories
*/
SELECT 'Customers' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('customers') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM customers

 UNION ALL

SELECT 'Products' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('products') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM products

 UNION ALL

SELECT 'ProductLines' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('productlines') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM productlines

 UNION ALL

SELECT 'Orders' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('orders') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM orders

 UNION ALL

SELECT 'OrderDetails' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('orderdetails') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM orderdetails

 UNION ALL

SELECT 'Payments' AS table_name,
       (SELECT COUNT(*) 
          FROM pragma_table_info('payments')
       ) AS number_of_attributes,
       COUNT(*) AS number_of_rows
  FROM payments
 
 UNION ALL

SELECT 'Employees' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('employees') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM employees

 UNION ALL

SELECT 'Offices' AS table_name, (SELECT COUNT(*)
                                     FROM pragma_table_info('offices') ) AS number_of_attributes,
        COUNT(*) AS number_of_rows
  FROM offices;

--  which products should we order more of or less of? 

WITH
low_stock AS (
    SELECT p.productName, p.productCode, p.productline,
           (SELECT ROUND(SUM(od.quantityOrdered)* 1.0 / (p.quantityInStock), 2)
              FROM orderdetails AS od
             WHERE p.productCode = od.productCode
        ) AS restock
      FROM products AS p
     GROUP BY p.productCode
     ORDER BY restock DESC
     LIMIT 10
),

product_performance AS (
    SELECT productCode, ROUND((SUM(quantityOrdered) * priceEach), 2)
        AS product_sales
      FROM orderdetails
     GROUP BY productCode
     ORDER BY product_sales DESC
     LIMIT 10
)

SELECT s.productName, s.restock
  FROM low_stock AS s
 WHERE s.productCode IN (SELECT productCode
                           FROM product_performance);

-- Question 2: How Should We Match Marketing and Communication Strategies to Customer Behavior?

WITH
vip_customer AS (
SELECT o.customerNumber, 
        (SUM(od.quantityOrdered * (od.priceEach - p.buyPrice))) AS profit
   FROM orders AS o
   JOIN orderdetails AS od
     ON o.orderNumber = od.orderNumber
   JOIN products AS p
     ON od.productCode = p.productCode
  GROUP BY o.customerNumber
  ORDER BY profit DESC
)

SELECT c.contactFirstName || " " || c.contactLastName, c.city, c.state, c.country,
       vc.profit
  FROM customers AS c
  JOIN vip_customer AS vc
    ON c.customerNumber = vc.customerNumber
  LIMIT 10;

-- Question 3: How Much Can We Spend on Acquiring New Customers?

WITH 

payment_with_year_month_table AS (
	SELECT *, 
           CAST((SUBSTR(paymentDate,1,4) || SUBSTR(paymentDate, 6,7)) AS INTEGER) AS year_month
      FROM payments p
),

customers_by_month_table AS (
	SELECT p1.year_month, COUNT(*) AS number_of_customers, SUM(p1.amount) AS total
	  FROM payment_with_year_month_table p1
	 GROUP BY p1.year_month
),

new_customers_by_month_table AS (
	SELECT p1.year_month, 
		   COUNT(*) AS number_of_new_customers,
		   SUM(p1.amount) AS new_customer_total,
		   (SELECT number_of_customers
			  FROM customers_by_month_table c
			 WHERE c.year_month = p1.year_month) AS number_of_customers,
		   (SELECT total
			  FROM customers_by_month_table c
			 WHERE c.year_month = p1.year_month) AS total
	  FROM payment_with_year_month_table p1
	 WHERE p1.customerNumber NOT IN (SELECT customerNumber
									   FROM payment_with_year_month_table p2
									  WHERE p2.year_month < p1.year_month)
	 GROUP BY p1.year_month
)

SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS number_of_new_customers_props,
       ROUND(new_customer_total*100/total,1) AS new_customers_total_props
  FROM new_customers_by_month_table;

WITH
customer_profit AS (
	SELECT o.customerNumber, 
		   SUM(od.quantityOrdered * (od.priceEach - p.buyPrice)) AS profit
	  FROM orders AS o
	  JOIN orderdetails AS od
	    ON o.orderNumber = od.orderNumber
	  JOIN products AS p
	    ON od.productCode = p.productCode
	 GROUP BY o.customerNumber
)
	SELECT AVG(profit) AS avg_customer_profit
	  FROM customer_profit;

/*

Classic cars are most in demand hence need frequent restocking. 
The stores customers prefer to buy classic cars and thye generate most incore for the company. 
Top 5 VIP customers generate over $60,000 each in rpofit for the store 
They come from Spain, USA, Australia, and France. 
The least engaged customers make the company around 10,000 in profit. 
All from different countries. 
Since the average customer profit is $39,040 it is worthwhile for the company to market to new customers 
and offer inctives to the existing VIP customers. 

*/