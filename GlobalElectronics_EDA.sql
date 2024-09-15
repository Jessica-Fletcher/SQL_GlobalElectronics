-- -- -- -- Customer Demographics and Segmentation -- -- -- --

-- What is the gender distribution of customers?

SELECT
	Gender,
    COUNT(*) as total_customers,
	ROUND(COUNT(*)/(SELECT count(*) FROM customers) * 100, 2) as pct_distribution
FROM customers
GROUP BY Gender;

-- Which country has the highest customer concentration?

SELECT Country, Count(*)
FROM customers
GROUP BY Country
ORDER BY 2 DESC
LIMIT 1;

-- Which state in the US has the highest customer concentration?

SELECT State, Count(*)
FROM customers
WHERE country = 'United States'
GROUP BY State
ORDER BY 2 DESC
LIMIT 1;

-- Which city in California has the highest customer concentration?

SELECT City, Count(*)
FROM customers
WHERE state = 'California'
GROUP BY City
ORDER BY 2 DESC
LIMIT 1;

-- Identify customer segments based on age

-- First, convert birthdays from strings to dates

SET sql_mode=''; # bug in SQL 

UPDATE customers SET Birthday = STR_TO_DATE(Birthday,'%c-%e-%Y');

ALTER TABLE customers
MODIFY COLUMN Birthday date;

-- Add age column, insert age as difference between current date and birthday

SELECT Birthday, TIMESTAMPDIFF(YEAR, Birthday,CURDATE()) as AGE
FROM customers;

ALTER TABLE customers
ADD COLUMN Age int;

UPDATE customers SET Age = TIMESTAMPDIFF(YEAR, Birthday,CURDATE());

SELECT *
FROM Customers;

-- Segment by age range, show quantity of products purachased

WITH cte AS (SELECT CustomerKey, 
	(CASE 
		WHEN Age between 18 and 24 then '18-24'
		when Age between 25 and 34 then '25-34'
		when Age between 35 and 44 then '35-44'
		when Age between 45 and 54 then '45-54'
		when Age between 55 and 64 then '55-64'
		ELSE '65 and older'
    END) as age_range
FROM customers)
SELECT 
	age_range, 
    COUNT(DISTINCT c.CustomerKey) as num_customers, 
    sum(s.quantity) as total_quantity
FROM 
	cte c
	JOIN sales s ON c.CustomerKey = s.CustomerKey
GROUP BY age_range
ORDER BY 2 DESC;

-- Segment by age range, show sales for each age range

with cte as 
	(SELECT CustomerKey,
		(case 
		when Age between 18 and 24 then '18-24'
		when Age between 25 and 34 then '25-34'
		when Age between 35 and 44 then '35-44'
		when Age between 45 and 54 then '45-54'
		when Age between 55 and 64 then '55-64'
		ELSE '65 and older'
		END) as age_range
	FROM customers)
SELECT 	age_range, 
		count(DISTINCT c.CustomerKey) as num_customers, 
        ROUND(SUM(p.UnitPriceUSD)) as total_sales
FROM cte c
JOIN sales s
ON c.CustomerKey = s.CustomerKey
JOIN products p
ON p.ProductKey = s.ProductKey
GROUP BY age_range
ORDER BY 2 DESC;

-- -- -- -- Store Performance and Geographic Analysis -- -- -- --

-- Which 5 store generates the highest revenue?

SELECT 
	st.StoreKey,
    ROUND(SUM(sa.quantity * p.UnitPriceUSD)) AS TotalSales
FROM stores st
JOIN sales sa
ON st.StoreKey = sa.StoreKey
JOIN products p
ON sa.ProductKey = p.ProductKey
GROUP BY st.StoreKey
ORDER BY 2 DESC
LIMIT 5;

-- Are there any coorelations between store size and sales performance?

SELECT
	st.StoreKey,
    st.SquareMeters,
    ROUND(SUM(sa.quantity * p.UnitPriceUSD)) AS TotalSales
FROM stores st
JOIN sales sa
ON st.StoreKey = sa.StoreKey
JOIN products p
ON sa.ProductKey = p.ProductKey
GROUP BY st.StoreKey, st.SquareMeters
ORDER BY st.SquareMeters DESC;

-- How does sales performance vary accross different countries or states?

-- countries

SELECT 
	st.Country,
    ROUND(SUM(sa.Quantity * p.UnitPriceUSD)) AS TotalSales
FROM stores st
JOIN sales sa
ON st.StoreKey = sa.StoreKey
JOIN products p
ON sa.ProductKey = p.ProductKey
GROUP BY st.Country
ORDER BY 2 DESC;

-- states

SELECT 
	st.State,
    ROUND(SUM(sa.Quantity * p.UnitPriceUSD)) AS TotalSales
FROM stores st
JOIN sales sa
ON st.StoreKey = sa.StoreKey
JOIN products p
ON sa.ProductKey = p.ProductKey
WHERE st.Country = 'United States'
GROUP BY st.State
ORDER BY 2 DESC;

-- -- -- --  Calculate the customer retention rate for 2019 -- -- -- -- 

-- using CRR = [(E-N)/S]x100

-- first, update OrderDate column from a string to a date

UPDATE sales SET OrderDate = STR_TO_DATE(OrderDate,'%c/%e/%Y');

ALTER TABLE sales
MODIFY COLUMN OrderDate date;

-- now, find the customers that existed before the start of 2019

SELECT 
	COUNT(DISTINCT CustomerKey)
FROM 
	sales
WHERE 
	OrderDate < '2019-01-01';
    
-- find the customers that were active during 2019
    
SELECT 
	COUNT(DISTINCT CustomerKey)
FROM
	sales
WHERE
	OrderDate BETWEEN '2019-01-01' AND '2019-12-31';
    
-- find the new customers in 2019

SELECT
	COUNT(DISTINCT CustomerKey)
FROM
	sales
WHERE CustomerKey NOT IN (
	SELECT 
	DISTINCT CustomerKey
FROM 
	sales
WHERE 
	OrderDate < '2019-01-01')
AND OrderDate BETWEEN '2019-01-01' AND '2019-12-31';
    
-- join the tables and calculate the retention rate
-- note: use cross join, since you are joining together aggregated results, and not joining on a specific condition
-- result of the cross join is a single row w/ ExisitingCount, NewCount, and ActiveCount; these are used to calulate CRR

WITH ExistingCustomers AS (
SELECT 
	COUNT(DISTINCT CustomerKey) AS ExistingCount
FROM 
	sales
WHERE 
	OrderDate < '2019-01-01'),
NewCustomers AS (
SELECT
	COUNT(DISTINCT CustomerKey) AS NewCount
    FROM
	sales
WHERE CustomerKey NOT IN (
	SELECT 
	DISTINCT CustomerKey
FROM 
	sales
WHERE 
	OrderDate < '2019-01-01')
AND OrderDate BETWEEN '2019-01-01' AND '2019-12-31'),
ActiveCustomers AS (
SELECT 
	COUNT(DISTINCT CustomerKey) AS ActiveCount
FROM
	sales
WHERE
	OrderDate BETWEEN '2019-01-01' AND '2019-12-31')
SELECT
	ROUND(100.0 * (ec.ExistingCount - nc.NewCount) / ac.ActiveCount, 2) AS CustomerRetentionRate
FROM ExistingCustomers ec
CROSS JOIN ActiveCustomers ac
CROSS JOIN NewCustomers nc;



