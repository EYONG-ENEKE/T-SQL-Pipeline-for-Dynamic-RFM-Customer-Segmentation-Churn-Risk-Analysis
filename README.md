# T-SQL Pipeline for Dynamic RFM Customer Segmentation & Churn Risk Analysis

T-SQL Pipeline for Dynamic RFM Customer Segmentation & Churn Risk Analysis 
Technical Documentation & Strategic Deployment Framework
1. Business Executive Summary
An initial automated execution and forensic review of the T-SQL customer analytics engineering pipeline has uncovered deep-seated diagnostic patterns in the transaction history. The metrics heavily suggest a critical need to adjust current acquisition and retention strategies to protect profit margins:
Severe Retention Deficit: The vast majority of the documented customer base resides inside deeply cold, inactive, or completely flatlined segments (typified by static '111' low-value indices) with prolonged dormancy stretching past 300+ days.
Data Vulnerabilities & Revenue Leakage: A clustering of profound negative monetary anomalies exists within the historical system logs (specifically localized around CustomerIDs 17448 and 15369). These flags show major refunds, credit reversals, or potential structural loopholes being exploited within transactional pipelines.
High Churn Exposure: Highly active, reliable, or high-spending premium buyers form an extremely small percentage of total records. The top-line commercial pipeline remains highly fragile and dependent on a concentrated, volatile tier of consumers.
2. System Architecture & Data Pipeline
The engine deploys a structural, three-tier data pipeline designed for native schema isolation, strict query performance, and script idempotency inside production Microsoft SQL Server (MSSQL) environments:
Step 1: Clean Isolation & Preparation
The engine dynamically drops legacy analytical viewpoints and volatile staging schemas (dbo.RFM_SEGMENT, dbo.other_segment, dbo.vw_customer_segments) to enforce clean execution bounds. An active operational backup sequence writes structural snapshots directly to the physical storage subsystem disk destination prior to mutation arrays.

Step 2: Core Processing & Statistical Binning
Raw parameters from underlying transaction ledgers (dbo.online_retail) pass through rigid filtration criteria to purge unassigned tracking keys, zero prices, and null attributes. The clean arrays feed into statistical distributions where NTILE(4) window ranks compute precise percentile placement for Recency (R), Frequency (F), and Monetary (M) scores.

Step 3: Downstream Multi-Tier Calculations
The computed base vectors inject final segmentation indices, unified concatenated system scores, Average Order Value (AOV), and mathematical extensions for forward-looking risk matrices directly into production tables.
3. Analytical Customer Lifetime Value Formulas
The technical database architecture tracks long-term monetization capacity using two separate mathematical value engines built directly into the execution scripts:
Model A: Fixed-Lifespan Projected CLV (Historical Baseline)
Designed to evaluate current run-rate monetization health against standard commercial boundaries. This formula uses an industry-standard static lifespan baseline alongside a strict gross margin parameter:
Projected CLV = (Historical Revenue * Gross Margin [40%]) * Assumed Lifespan [3 Years]
Model B: Predictive Churn-Adjusted Net CLV (Dynamic Framework)
An advanced framework designed to compute value based on dynamic behavior patterns, scaling directly against purchase frequency and annualized enterprise risk factors:
Predictive Net CLV = (Average Order Value * Annual Purchase Frequency * Gross Margin [40%]) / Churn Rate [25%]

4. Tactical Segmentation Mapping Matrix
The deployment script converts numeric multi-dimensional data vectors into clear, execution-focused operational categories via the dbo.vw_customer_segments view infrastructure:
Model A: Fixed-Lifespan Projected CLV (Historical Baseline)
Tactical Segment
RFM Metrics
Core Strategic Deployment
Champions / VIP
R≥4,F≥4,M≥4
Deploy elite retention tracks, high-touch support perks, and automated early beta access loops.
Loyal Customers
R≥3,F≥4
Inject structured advocacy tracking, brand loyalty milestones, and personalized referral bonuses.
Promising New
R≥4,F=1
Execute fast-tracked transactional onboarding tracks to drive the critical second-order conversion.
Big Spenders
M≥4,F≤2
Introduce customized cross-sell recommendations and bundled, high-ticket package incentives.
At Risk / Churn
R≤2,F≥3
Trigger priority win-back pricing, customer satisfaction check-ins, and direct engagement offers.
Lost / Dormant
R≤1,F≤1
Route to zero-ad-spend email nurture monitors; preserve expensive marketing capital.
Mid-Tier Standard
Balanced Blends
Apply sub-tier micro-groupings (High, Core, Marginal) to capture hidden upsell upside cleanly.


5. Strategic Action Plan & Data-Driven Recommendations
1. Audit High-Volume Negative Transaction Clusters
Isolate, map, and audit transaction streams for CustomerID 17448 and 15369. Data engineering teams must confirm if the negative monetary values are unlinked historical returns or systematic returns loopholes that require platform-level security patches.

2. Monetize Active, Low-Spending Fast Movers
Target highly active recent shoppers (such as CustomerIDs 14785 and 16789, who purchased <10 days ago but sit in the lowest volume tier). Use real-time check-out cross-sells or immediate email bundles to successfully boost their baseline Average Order Value (AOV).

3. Freeze Paid Ad Spend on Dead Core Targets
Completely suppress the large cluster of '111' core dormant accounts (inactive for >300 days) from custom audience uploads to Meta, Google, and paid marketing networks. Reallocate that budget to high-yield VIP cohorts and route dead metrics exclusively to zero-cost automated email reactivation tracks.


