# manga-data-analysis

This SQL script documents my complete end-to-end data preparation workflow for the **Manga Analytics Project**, built entirely inside Microsoft Azure SQL Database.

### 📌 What’s inside:
- 🔍 **Exploratory analysis** of the raw manga dataset  
- 🧼 **Data cleaning** (handling nulls, malformed JSON, and inconsistent strings)  
- 🧩 **Normalization** of complex columns like `genres`, `themes`, `authors`, and `demographics` into many-to-many relationships  
- 🛠️ Use of `OPENJSON()` to parse and flatten embedded author data stored in JSON format  
- 🧪 Safe type conversions using `TRY_CAST()`, `ISJSON()`, and `COALESCE()`  
- 🧹 Schema simplification through selective `DROP COLUMN` and renaming  
- 📊 Early steps toward **building reusable views and metrics** for reporting in Tableau  

This script represents the **foundational logic** and iterative thought process that led to the final data model and star schema used in the project.
