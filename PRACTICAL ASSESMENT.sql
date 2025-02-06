--  1. Retrieve the names of all employees who have sold more than the average sales amount YTD
--  across all salespersons.
WITH cte_ytd AS
(
	SELECT
		pp.BusinessEntityID,
		pp.FirstName,
		pp.LastName,
		sp.SalesYTD 
	FROM adv.sales_salesperson AS sp 
	JOIN adv.person_person AS pp 
		ON sp.BusinessEntityID = pp.BusinessEntityID   
)
SELECT *
FROM cte_ytd
WHERE SalesYTD > 
(
	SELECT avg(SalesYTD) 
	FROM cte_ytd
);

-- 2. Retrieve the top 3 employees with the highest sales YTD for each territory
WITH cte_sales AS 
(
	SELECT
		sp.BusinessEntityID,
		pp.FirstName,
		pp.LastName,
		sp.SalesYTD,
		st.Name,
		RANK () OVER (PARTITION BY Name ORDER BY SalesYTD DESC) AS SalesRank
	FROM adv.sales_salesperson AS sp
	JOIN adv.person_person AS pp
		ON sp.BusinessEntityID = pp.BusinessEntityID 
	JOIN adv.sales_salesterritory AS st 
		ON sp.TerritoryID = st.TerritoryID 
)
SELECT *
FROM cte_sales AS s
WHERE SalesRank < 4; 


-- 3. For each employee, retrieve the YTD sales and the difference between their sales and the
--  average sales of their territory
WITH cte_avgsales_by_territory AS 
(
	SELECT
		TerritoryID,
		Name,
		avg(SalesYTD) AS AvgSales
	FROM adv.sales_salesterritory 
	GROUP BY TerritoryID 
	ORDER BY AvgSales DESC
), 
cte_employee_sales AS 
( 
	SELECT 
		sp.BusinessEntityID AS Employee,
		FirstName,
		LastName, 
		SalesYTD, 
		TerritoryID
	FROM adv.sales_salesperson AS sp 
	JOIN adv.person_person AS pp 
		ON sp.BusinessEntityID = pp.BusinessEntityID 
)
SELECT 
	FirstName,
	LastName,
	SalesYTD,
	AvgSales - SalesYTD AS Difference,
	Name
FROM cte_avgsales_by_territory AS sbt
JOIN cte_employee_sales AS es 
	ON sbt.TerritoryID = es.TerritoryID;

	
-- 4. Retrieve a list of all products that have been sold in the second quarter of 2012.
WITH cte_products AS 
(
	SELECT DISTINCT 
		sod.ProductID,
		Name,
		YEAR(OrderDate) AS OrderYear,
		quarter(OrderDate) Quarter
	FROM adv.sales_salesorderheader AS soh
	JOIN adv.sales_salesorderdetail AS sod 
		ON soh.SalesOrderID = sod.SalesOrderID 
	JOIN adv.production_product AS pp
		ON sod.ProductID = pp.ProductID 
)
SELECT *
FROM cte_products
WHERE OrderYear = 2012 AND Quarter = 2;


--  5. Retrieve the names of the current employees who are in either the sales or marketing
--  departments.
SELECT
	pp.FirstName,
	pp.LastName,
	hd.Name 
FROM adv.humanresources_employeedepartmenthistory AS edh 
JOIN adv.humanresources_department AS hd 
	ON edh.DepartmentID = hd.DepartmentID 
JOIN adv.person_person AS pp 
	ON edh.BusinessEntityID = pp.BusinessEntityID 
WHERE Name IN ('Sales', 'Marketing')
AND edh.EndDate IS NULL;

--  6. Retrieve the id’s and names of all products that have not been sold in the first half of 2013.
WITH cte_products_2013 AS 
(
	SELECT DISTINCT  
		ProductID,
		Year(OrderDate) AS OrderYear,
		quarter(OrderDate) AS YearQuarter  
	FROM adv.sales_salesorderheader AS soh 
	JOIN adv.sales_salesorderdetail AS sod 
		ON soh.SalesOrderID = sod.SalesOrderID 
	WHERE Year(OrderDate) = 2013 
	AND quarter(OrderDate) IN (1, 2)
)
SELECT DISTINCT 
	sod.ProductID,
	Name 
FROM adv.sales_salesorderdetail AS sod 
JOIN adv.production_product AS pp
	ON sod.ProductID = pp.ProductID
WHERE sod.ProductID NOT IN (SELECT ProductID FROM cte_products_2013);

--  7. Retrieve a list of customers and their total purchase amounts for orders placed in the second
--  half of 2013, but only include customers from the ’Northwest’ or ’Southwest’ sales territories.
WITH cte_total_purchase AS 
(
	SELECT DISTINCT 
		CustomerID,
		SUM(SubTotal) AS PurchaseAmount,
		TerritoryID,
		YEAR(OrderDate) AS OrderYear,
		CASE 
			WHEN MONTH(OrderDate) < 7 THEN '1st Half'
		ELSE '2nd Half'
		END AS HalfYear
	FROM adv.sales_salesorderheader AS soh 
	GROUP BY CustomerID, TerritoryID, OrderYear, HalfYear
	ORDER BY PurchaseAmount DESC 
),
cte_by_territory AS 
(	
	SELECT DISTINCT 
		tp.CustomerID,
		pp.FirstName,
		pp.LastName, 
		tp.PurchaseAmount,
		st.Name,
		tp.OrderYear,
		tp.HalfYear
	FROM cte_total_purchase AS tp 
	JOIN adv.sales_salesterritory AS st 
		ON tp.TerritoryID = st.TerritoryID
	JOIN adv.person_person AS pp 
		ON tp.CustomerID = pp.BusinessEntityID
	WHERE st.Name IN ('Northwest', 'Southwest') AND HalfYear = '2nd Half' AND OrderYear = 2013
)
SELECT CustomerID, FirstName, LastName
FROM cte_by_territory;


--  8. Retrieve cumulative yearly sales for each salesperson.
WITH cte_yearly_sales AS 
(
	SELECT 
		SalesPersonID,
		SUM(SubTotal) AS TotalSales,
		YEAR(OrderDate) AS SalesYear
	FROM adv.sales_salesorderheader AS soh
	WHERE SalesPersonID IS NOT NULL
	GROUP BY SalesPersonID, SalesYear 
)
SELECT 
	SalesPersonID,
	FirstName,
	LastName,
	TotalSales,
	SalesYear,
	SUM(TotalSales) OVER (PARTITION BY SalesPersonID ORDER BY SalesYear) CumulativeSales
FROM cte_yearly_sales AS ys
JOIN adv.person_person AS pp
	ON ys.SalesPersonID = pp.BusinessEntityID ;


--  9. Retrieve the names of all products whose average order quantity is greater than the average
--  order quantity across all products.
WITH cte_individual_qty AS 
(
	SELECT 
		ProductID, 
		AVG(OrderQty) AvgOrderQty
	FROM adv.sales_salesorderdetail
	GROUP BY ProductID 
	ORDER BY AvgOrderQty DESC 
)
SELECT 
	cte.ProductID,
	pp.Name,
	AvgOrderQty
FROM cte_individual_qty AS cte 
JOIN adv.production_product AS pp
	ON cte.ProductID = pp.ProductID 
WHERE AvgOrderQty > (SELECT avg(OrderQty) FROM adv.sales_salesorderdetail);


--  10. Retrieve the total number of orders per state for customers who live in California, Oregon,
--  and Washington.
SELECT
	sp.Name,
	count(SalesOrderID) AS OrderNum
FROM adv.sales_salesorderheader AS soh 
JOIN adv.person_stateprovince AS sp 
	ON soh.TerritoryID = sp.TerritoryID 
WHERE sp.Name IN ('California', 'Oregon', 'Washington')
GROUP BY sp.Name
ORDER BY OrderNum DESC;

