
/*
PROJECT TITLE: T-SQL Pipeline for Dynamic RFM Customer Segmentation & Churn Risk Analysis
*/


---------------------------------------------------------------------------------
-- ENVIRONMENT SETUP & SAFETY CHECKS
---------------------------------------------------------------------------------
backup Database PROJECT1
To Disk  = 'B:\MSSQL\PRODBACKUP\online_retail_FULL_10JUNE2026.bak'

---------------------------------------------------------------------------------
-- ANALYSIS ON CUSTOMER BEHAVIOUR USING THE RFM & CLV EXTENSION MODEL
---------------------------------------------------------------------------------

-- Clean up any pre-existing analytical tables to ensure script idempotency
DROP TABLE IF EXISTS dbo.RFM_SEGMENT;
DROP TABLE IF EXISTS dbo.other_segment;
DROP VIEW IF EXISTS dbo.vw_customer_segments;

-- Establish baseline assumptions for the Advanced CLV formula features
DECLARE @GrossMargin FLOAT = 0.40;       -- Assume a 40% retail gross margin
DECLARE @AvgLifespanYears FLOAT = 3.0;   -- Assume average customer relationship lasts 3 years

---------------------------------------------------------------------------------
-- CORE DATA PROCESSING LAYER: RFM BASE TABLE CONSTRUCTION
---------------------------------------------------------------------------------
WITH MaxDateAnchor AS (
    -- Compute the dataset's max date once to avoid repeating heavy scans
    SELECT MAX(InvoiceDate) AS MaxDatasetDate 
    FROM dbo.online_retail
),

base_data AS (
    SELECT 
        CustomerID,
        InvoiceNo,
        InvoiceDate,
        UnitPrice * Quantity AS Amount,
        Quantity
    FROM dbo.online_retail
    WHERE CustomerID IS NOT NULL
        AND Quantity > 0
        AND UnitPrice > 0
),

rfm_raw AS (
    SELECT
        b.CustomerID,
        MAX(b.InvoiceDate) AS LastPurchaseDate,
        DATEDIFF(DAY, MAX(b.InvoiceDate), m.MaxDatasetDate) AS Recency,
        COUNT(DISTINCT b.InvoiceNo) AS Frequency,
        SUM(b.Amount) AS Monetary,
        SUM(b.Quantity) AS TotalUnits
    FROM base_data b
    CROSS JOIN MaxDateAnchor m
    GROUP BY b.CustomerID, m.MaxDatasetDate
),

rfm_score AS (
    SELECT 
        *,
        -- ORDER BY Recency ASC guarantees that low days-since-purchase equals the highest score (4)
        NTILE(4) OVER (ORDER BY Recency ASC) AS R_Score, 
        NTILE(4) OVER (ORDER BY Frequency DESC) AS F_Score,   
        NTILE(4) OVER (ORDER BY Monetary DESC) AS M_Score     
    FROM rfm_raw
)
SELECT 
    *,
    -- FIXED: Wrapped in proper CASE syntax, added END, and provided clear column names
    CASE 
        WHEN R_Score = 1 THEN 'Longest Dormant'
        WHEN R_Score = 2 THEN 'Dormant'
        WHEN R_Score = 3 THEN 'Recent'
        WHEN R_Score = 4 THEN 'Most Recent'
    END AS Recency_Label,
    
    CASE 
        WHEN F_Score = 1 THEN 'Lowest Volume'
        WHEN F_Score = 2 THEN 'Frequent'
        WHEN F_Score = 3 THEN 'More Frequent'
        WHEN F_Score = 4 THEN 'Most Frequent'
    END AS Frequency_Label,
    
    CASE 
        WHEN M_Score = 1 THEN 'Lowest Spend'
        WHEN M_Score = 2 THEN 'Moderately Spend'
        WHEN M_Score = 3 THEN 'More Spend'
        WHEN M_Score = 4 THEN 'Most Spend'
    END AS Monetary_Label,
    
    CONCAT(R_Score, F_Score, M_Score) AS RFM_Score,
    CAST(Monetary / NULLIF(Frequency, 0) AS DECIMAL(10,2)) AS AvgOrderValue_AOV,
    CAST((Monetary * @GrossMargin) * @AvgLifespanYears AS DECIMAL(10,2)) AS Projected_CLV
INTO dbo.RFM_SEGMENT
FROM rfm_score;

-- Verify structural build
SELECT * FROM dbo.RFM_SEGMENT ORDER BY Monetary DESC;

---------------------------------------------------------------------------------
-- OBJECTIVE EXTRACTION QUERIES (BUSINESS INTELLIGENCE LAYER)
---------------------------------------------------------------------------------

-- 1. VIP Customers (High-Value Segment)
SELECT 
    CustomerID, Recency, Frequency, Monetary, RFM_Score, Projected_CLV
FROM dbo.RFM_SEGMENT
WHERE R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4
ORDER BY Monetary DESC;

-- 2. At-Risk Customers (Churn Detection & Prevention)
SELECT 
    CustomerID, Recency, Frequency, Monetary, RFM_Score, Projected_CLV
FROM dbo.RFM_SEGMENT
WHERE R_Score <= 2   
  AND F_Score >= 3   
  AND M_Score >= 4   
ORDER BY Recency DESC;

-- 3. Dormant High-Spenders (Reactivation Target)
WITH MonetaryPercentiles AS (
    SELECT 
        *,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Monetary) OVER () AS P75_Monetary
    FROM dbo.RFM_SEGMENT
)
SELECT CustomerID, Recency, Frequency, Monetary, Projected_CLV
FROM MonetaryPercentiles
WHERE Recency > 90 
  AND Monetary >= P75_Monetary
ORDER BY Monetary DESC;

-- 4. Marketing Spend Optimization Segments
SELECT 
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 THEN 'High Priority (Engaged Value)'
        WHEN R_Score >= 3 AND F_Score >= 3 THEN 'Medium Priority (Nurture)'
        ELSE 'Low Priority (Cold / Low Value)'
    END AS Budget_Segment,
    COUNT(*) AS CustomerCount,
    SUM(Monetary) AS Total_Revenue,
    AVG(Projected_CLV) AS Average_Projected_CLV
FROM dbo.RFM_SEGMENT
GROUP BY 
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 THEN 'High Priority (Engaged Value)'
        WHEN R_Score >= 3 AND F_Score >= 3 THEN 'Medium Priority (Nurture)'
        ELSE 'Low Priority (Cold / Low Value)'
    END
ORDER BY Total_Revenue DESC;

-- 5. Personalized Promotion Segments
SELECT 
    CustomerID,
    RFM_Score,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 THEN 'VIP - Loyalty Rewards & Exclusives'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk - Winback High-Discount Incentives'
        WHEN F_Score = 1 THEN 'New - Welcome Onboarding Offers'
        ELSE 'Standard Contextual Campaign'
    END AS PromotionStrategy
FROM dbo.RFM_SEGMENT;

-- 6. Customer Lifetime Value (CLV Realization Matrix)
SELECT 
    CustomerID,
    Frequency,
    Monetary,
    AvgOrderValue,
    Projected_CLV
FROM dbo.RFM_SEGMENT
ORDER BY Projected_CLV DESC;

-- 7. Low-Value / Unprofitable Customers (Minimize Resource Drain)
SELECT 
    CustomerID, Recency, Frequency, Monetary, RFM_Score
FROM dbo.RFM_SEGMENT
WHERE F_Score <= 2 AND M_Score <= 2
ORDER BY Monetary ASC;

-- 8. Granular Purchase Behavior & Basket Analysis by Segment
SELECT 
    r.RFM_Score,
    COUNT(DISTINCT r.CustomerID) AS UniqueCustomers,
    AVG(r.Monetary) AS AvgTotalSpend,
    AVG(r.Frequency) AS AvgPurchaseFrequency,
    SUM(b.Quantity) AS TotalUnitsPurchased,
    CAST(SUM(b.UnitPrice * b.Quantity) / NULLIF(SUM(b.Quantity), 0) AS DECIMAL(10,2)) AS AvgUnitWholesalePrice
FROM dbo.RFM_SEGMENT r
JOIN dbo.online_retail b ON r.CustomerID = b.CustomerID
GROUP BY r.RFM_Score
ORDER BY AvgTotalSpend DESC;

-- 9. Demand & Inventory Planning (Predictable Heavy Buyers)
SELECT 
    CustomerID, Frequency, Monetary, TotalUnits
FROM dbo.RFM_SEGMENT
WHERE F_Score >= 4
ORDER BY TotalUnits DESC;

---------------------------------------------------------------------------------
-- PRODUCTION ANALYTICS LAYER: VIEW CREATION & MICRO-SEGMENTATION
---------------------------------------------------------------------------------
GO

CREATE VIEW dbo.vw_customer_segments AS
SELECT *,
    CASE 
        WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions / VIP'
        WHEN R_Score >= 3 AND F_Score >= 4 THEN 'Loyal Customers'
        WHEN R_Score >= 4 AND F_Score = 1 THEN 'Promising New Customers'
        WHEN M_Score >= 4 AND F_Score <= 2 THEN 'Big Spenders (Infrequent)'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk / High Churn Likelihood'
        WHEN R_Score <= 1 AND F_Score <= 1 THEN 'Lost / Dormant'
        ELSE 'Mid-Tier Standard'
    END AS Tactical_Segment
FROM dbo.RFM_SEGMENT;

GO

-- Verify View output
SELECT * FROM dbo.vw_customer_segments;

-- 10. Refining the "Others / Mid-Tier" Segment cleanly
SELECT * INTO dbo.other_segment FROM dbo.vw_customer_segments WHERE Tactical_Segment = 'Mid-Tier Standard';

WITH OptimizedMidTier AS ( 
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        Tactical_Segment,
        NTILE(3) OVER (ORDER BY Monetary DESC) AS Value_Tier_Group
    FROM dbo.other_segment
)
SELECT  
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    CASE 
        WHEN Value_Tier_Group = 1 THEN 'Mid-Tier High Value (Upsell Candidate)'
        WHEN Value_Tier_Group = 2 THEN 'Mid-Tier Core Stable'
        ELSE 'Mid-Tier Marginal Value'
    END AS Refined_Analytical_Label
FROM OptimizedMidTier;

                               ----interpretation of results----
/*The RFM analysis revealed that the majority of customers belong to low-value and dormant segments characterized by infrequent purchases, low spending behavior, and prolonged inactivity periods.
A considerable number of customers also exhibited negative monetary values, suggesting possible refunds, chargebacks, or operational losses. 
Only a limited proportion of customers were classified as recent and frequent buyers, although their spending levels remained relatively low.
Overall, the findings indicate weak customer retention, low customer lifetime value, and a high risk of customer churn within the business.*/
                         
                         ---Recommendation---
/* 
1.Investigate the High Negative Rows: Look into Customers 17448 and 15369.
Is your system recording refunds without capturing the initial sales, or did these individuals successfully exploit a return loophole?

2.Ignite the Active Low-Spenders (421 and 321): Customers like 14785 (10 days ago) and 16789 (8 days ago) are active right now. 
Since they fall into "Lowest Spend", try cross-selling or upselling higher-value items to bump them into a higher Monetary tier.

3.Do Not Waste Ad Spend on the 111s: The sheer volume of 111 customers who haven't purchased in ~300+ days are heavily dragging down your averages.
Exclude them from standard email/ad campaigns to save costs, or relegate them to a low-cost "Win-Back" automation sequence.*/



---                            CALCULATION OF CLV

-- Define the assumed average lifespan of a customer in years (e.g., 3 years)
DECLARE @AverageLifespanYears FLOAT = 3.0;

WITH CustomerMetrics AS (
    -- Step 1: Calculate core aggregates per customer
    SELECT 
        CustomerID,
        COUNT([InvoiceNo]) AS TotalOrders,
        sum([UnitPrice]*[Quantity]) AS HistoricalCLV, -- Total revenue generated so far
        MIN([InvoiceDate]) AS FirstOrderDate,
        MAX([InvoiceDate]) AS LastOrderDate,
        -- Calculate individual lifespan in years based on their activity span
        DATEDIFF(day,  MIN([InvoiceDate]), MAX([InvoiceDate])) / 365.25 AS ActiveLifespanYears
    FROM 
      [dbo].[online_retail] 
    GROUP BY 
        CustomerID
),
CLVFactors AS (
    -- Step 2: Calculate Average Order Value (AOV) and Purchase Frequency
    SELECT 
        CustomerID,
        TotalOrders,
        HistoricalCLV,
        ActiveLifespanYears,
        -- Avoid division by zero if TotalOrders is somehow 0
        CASE 
            WHEN TotalOrders > 0 THEN HistoricalCLV / TotalOrders 
            ELSE 0 
        END AS AverageOrderValue,
        -- Frequency: Orders per year (Default to 1 if lifespan is less than a year to avoid skewing)
        CASE 
            WHEN ActiveLifespanYears > 0 THEN TotalOrders / ActiveLifespanYears
            ELSE TotalOrders
        END AS PurchaseFrequencyPerYear
    FROM 
        CustomerMetrics
)
-- Step 3: Put it all together to calculate Estimated CLV
SELECT 
    CustomerID,
    TotalOrders,
    ROUND(HistoricalCLV, 2) AS HistoricalCLV,
    ROUND(AverageOrderValue, 2) AS AverageOrderValue,
    ROUND(PurchaseFrequencyPerYear, 1) AS PurchaseFrequencyPerYear,
    -- Formula: AOV * Purchase Frequency * Constant Lifespan
    ROUND(AverageOrderValue * PurchaseFrequencyPerYear * @AverageLifespanYears, 2) AS EstimatedCLV
FROM 
    CLVFactors
ORDER BY 
    EstimatedCLV DESC;
/*  Ways to Customize This Query
Filter out Outliers: If you have wholesale or B2B clients mixed with retail customers, add a WHERE clause to filter them out, as they will heavily distort your averages.

Use Gross Profit Instead of Revenue: True CLV is often calculated using profit margins. If you have a profit margin metric, multiply TotalAmount by your margin percentage (e.g., SUM(TotalAmount * 0.40)) to get a more accurate net CLV.

Dynamic Lifespan: Instead of a hardcoded @AverageLifespanYears = 3.0, you can calculate the actual average lifespan of your churned customers and plug that average directly into the formula.*/




/* CLV = (Average Order Value * Annual Purchase Frequency * Profit Margin) /  Churn Rate */

SELECT 
    Metrics.CustomerID,
    Metrics.TotalOrders,
    ROUND(Metrics.HistoricalRevenue, 2) AS HistoricalRevenue,
    ROUND(Metrics.AOV, 2) AS AverageOrderValue,
    ROUND(Metrics.AnnualFrequency, 1) AS AnnualFrequency,
    
    -- Final Calculation: (AOV * Frequency * Margin) / Churn Rate
    ROUND(
        (Metrics.AOV * Metrics.AnnualFrequency * 0.40) / 0.25, 
        2
    ) AS PredictiveNetCLV
FROM 
    (
        -- Derived Table: Aggregates base data and calculates frequency in a single pass
        SELECT 
            CustomerID,
            COUNT([InvoiceNo]) AS TotalOrders,
            SUM([UnitPrice]*[Quantity]) AS HistoricalRevenue,
            -- Calculate Average Order Value (AOV) directly
            SUM([UnitPrice]*[Quantity]) /  COUNT([InvoiceNo]) AS AOV,
            -- Calculate Annual Purchase Frequency inline
            CASE 
                WHEN DATEDIFF(DAY, MIN([InvoiceDate]), MAX([InvoiceDate])) > 0 
                THEN (COUNT([InvoiceNo])* 365.25) / DATEDIFF(DAY, MIN([InvoiceDate]), MAX([InvoiceDate]))
                ELSE  COUNT([InvoiceNo])
            END AS AnnualFrequency
        FROM 
           [dbo].[online_retail] 
        GROUP BY 
            CustomerID
    ) AS Metrics
ORDER BY 
    PredictiveNetCLV DESC;



