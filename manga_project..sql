/* This is day 1 of my Anime and Manga data analysis project -- 2025-05-13

The Goal of this passion project is to answer as many questions that may arise as I explore the dataset, as it is my first project in Azure database I will most likely
keep updating in the future.


I decided to start exploring the Manga dataset as the first question that comes to my mind is to find the commonalities that exist between successful manga,
I want to essentially find out if there is a success formula that authors follow in terms of theme, characters, genres, etc...

To answer this question I asked ChatGPT's help to review the files and help me find the crucial KPIs and metrics:

1. Manga Poplarity [AVG(score), readership count, # of favorites]
2. Genre Popularity [# of titles released per genre, AVG(score) per genre]
3. Trends by year [# titles released by year, AVG(score) per year]
4. Authors [AVG(score) per author, most popular demographic] 

*/
-- Check column's data type

SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'normalized_manga'
-- Prevent Errors, make sure all the values in score can be converted to float: 

SELECT score,
FROM dbo.manga
WHERE TRY_CAST(score AS FLOAT) IS NULL AND score IS NOT NULL;


-- Use ALTER TABLE ALTER COLUMN to permanently change the column's data type 
ALTER TABLE dbo.manga 
ALTER COLUMN score/members/favorites FLOAT;

-- Use ALTER TABLE DROP COLUMN to drop redundant or unnecessary data

ALTER TABLE normalized_manga
DROP COLUMN real_start_date, real_end_date;

-- Convert GENRES into a normalized many-to-many relational structure:

SELECT 
manga_id,
title,
LOWER(TRIM(VALUE)) AS genre -- Use LOWER() to transform all values into all lowercase
INTO normalized_genres
FROM dbo.manga
CROSS APPLY STRING_SPLIT(genres, ',');

UPDATE normalized_genres -- Fix the dirty genre values
SET genre = LOWER(
                TRIM(
                    REPLACE(
                        REPLACE(
                            REPLACE(genre, '[', ''), 
                            ']', ''), 
                        '''', '')
                )
            );

UPDATE normalized_genres -- Handle null values in genre
SET genre = 'not recorded'
WHERE genre = ' ' 

-- ## REPEAT SAME PROCESS FOR themes, demographics COLUMNS

SELECT demographics 
FROM normalized_manga;

UPDATE normalized_manga 
SET demographics = LOWER(
TRIM(
REPLACE(REPLACE(demographics, '[', ' '), ']', ' ')));

UPDATE [dbo].[normalized_manga]
SET demographics = 'not recorded' 
WHERE demographics = ' '

/* Now moving on to the authors column, I remembered I need to normalize this column into 
a new table.

After asking chatGPT for help I discovered that STRING_SPLIT can only be used
in simple delimited strings like: " Motomi, Minamoto".

Since this is a JSON array, I can use SQL Server’s OPENJSON() function to parse the authors into rows.
*/


SELECT TOP 5 manga_id, authors -- Filters rows where 'authors' contains valid JSON.
FROM dbo.manga -- ISJSON() returns 1 for well-formed JSON, 0 for invalid, NULL if null.
WHERE ISJSON(authors) = 0; -- Prevents errors when using JSON functions like OPENJSON or JSON_VALUE.

-- Step 2: Parse the JSON array and extract structured author info
-- Clean malformed JSON and filter for valid JSON only

WITH cleaned AS (
    SELECT 
        manga_id,
        -- Replace bad formatting to convert to proper JSON syntax:
        --   - single quotes → double quotes
        --   - Python-style None → empty string ""
        --   - True/False → lowercase true/false
        REPLACE(REPLACE(REPLACE(REPLACE(authors, '''', '"'), 'None', '""'), 'True', 'true'), 'False', 'false') AS authors_json
    FROM dbo.manga 
    -- Keep only rows where the cleaned version is valid JSON (avoids OPENJSON errors)
    WHERE ISJSON(REPLACE(REPLACE(REPLACE(REPLACE(authors, '''', '"'), 'None', '""'), 'True', 'true'), 'False', 'false')) = 1
)

-- Step 2: Parse the cleaned JSON array and extract individual author details
SELECT 
    c.manga_id,
    -- Extract the 'id' field from each author JSON object
    JSON_VALUE(a.value, '$.id') AS author_id,
    -- Extract 'first_name', replace empty strings with 'N/A'
    COALESCE(NULLIF(JSON_VALUE(a.value, '$.first_name'), ''), 'N/A') AS first_name,
    -- Extract 'last_name', replace empty strings with 'N/A'
    COALESCE(NULLIF(JSON_VALUE(a.value, '$.last_name'), ''), 'N/A') AS last_name,
    -- Extract 'role', replace empty strings with 'N/A'
    COALESCE(NULLIF(JSON_VALUE(a.value, '$.role'), ''), 'N/A') AS role
    INTO normalized_authors
FROM cleaned AS c
-- Decompose the JSON array in 'authors_json' into rows
CROSS APPLY OPENJSON(c.authors_json) a;

/* The ISJSON(...) in the WHERE clause is being applied to the cleaned version of the column:

sql

ISJSON(REPLACE(REPLACE(REPLACE(REPLACE(authors, '''', '"'), 'None', '""'), 'True', 'true'), 'False', 'false')) = 1

This means:

You’re not filtering for rows where the original authors is valid JSON.

You’re filtering for rows where the cleaned version of authors becomes valid JSON.

 Why It's Necessary:
Not all rows can be salvaged by a simple REPLACE() cleanup. Some rows may still have:

Structural issues (e.g. missing brackets, stray commas)

Unexpected nesting or non-array types

Totally unrelated garbage (like random text)

Without the ISJSON(...) = 1 check, those rows would throw an error when passed to OPENJSON().
*/ 

-- Drop the newly normalized tables from the normalized_manga table

ALTER TABLE normalized_manga
DROP COLUMN genres, themes;

/* Day 3 of this project, day 2 is not recorded due to the fact I spent most of it re-doing everything from day one 
to build a cleaner and better modularized database, as I noticed many rookie mistakes I did on day 1, like updating the original 
table instead of a copy, not keeping normalized tables' relationships to the main table, etc.

The original day 1 code was deleted and replaced by the work I did on day 2. */

-- Create author_trends VIEW once the columns are dropped

CREATE VIEW author_trends AS 
SELECT
    a.author_id,
    a.first_name || ' ' || a.last_name AS author_name,
    COUNT(DISTINCT m.manga_id) AS total_titles,
    AVG(m.score) AS avg_score,
    AVG(m.favorites) AS avg_favorites,
    AVG(m.members) AS avg_members,
    MIN(m.start_date) AS first_publication,
    MAX(m.start_date) AS latest_publication
FROM normalized_authors AS a 
LEFT JOIN nomalized_manga AS m 
ON a.manga_id = m.manga_id 
GROUP BY a.author_id, a.first_name, a.last_name;

-- Create genre performance view 

CREATE VIEW genre_trends AS
SELECT
    g.genre,
	COUNT(DISTINCT m.manga_id) AS total_titles,
	AVG(m.members * 1 + m.favorites * 3) AS avg_popularity_score,
    ROUND(AVG(m.score),2) AS avg_score,
    AVG(m.favorites) AS avg_favorites,
    AVG(m.members) AS avg_members
FROM normalized_genres AS g
LEFT JOIN normalized_manga AS m -- Joining on manga_id without selecting it, keeps the relationship to normalized_manga without having to group by it
ON m.manga_id = g.manga_id
GROUP BY g.genre;

/* I had the idea of creating a report of "Underrated Gems", I planned to do this
by first utilizing the popularity score formula to create a ranking,
with that ranking I would then filter the best performing titles and label them "Underrated Gens" 
if they exist in a percentile higher than 
*/

WITH popularity_data AS (
    SELECT 
        m.manga_id,
        m.title,
        m.score,
        m.members,
        m.favorites,
         (m.members*1 + favorites*3) AS popularity_score
    FROM normalized_manga AS m 
    WHERE m.members IS NOT NULL AND m.favorites IS NOT NULL
),

ranked_data AS (
    SELECT *,
           DENSE_RANK() OVER(ORDER BY popularity_score DESC) AS popularity_rank
    FROM popularity_data
),

with_percentile AS (
    SELECT *,
    1.0 * (popularity_rank - 1) / COUNT(*) OVER() AS popularity_percentile
    FROM ranked_data
)

SELECT * 
FROM with_percentile
ORDER BY popularity_percentile ASC;

-- I was impressed at myself after creating this data model and decided to do the same for genres and authors.

WITH genre_aggregated AS (
    SELECT
        g.genre,
        COUNT(DISTINCT m.manga_id) AS total_titles,
        ROUND(AVG(m.score), 2) AS avg_score,
        SUM(m.members) AS total_members,
        SUM(m.favorites) AS total_favorites,
        SUM(m.members * 1 + m.favorites * 3) AS total_popularity_score
    FROM normalized_genres g
    LEFT JOIN normalized_manga m 
      ON m.manga_id = g.manga_id
    WHERE m.members IS NOT NULL AND m.favorites IS NOT NULL
    GROUP BY g.genre
),

genre_ranked AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY total_popularity_score DESC) AS popularity_rank
    FROM genre_aggregated
),

with_genre_percentile AS (
    SELECT *,
           1.0 * (popularity_rank - 1) / COUNT(*) OVER () AS popularity_percentile
    FROM genre_ranked
)

SELECT *
FROM with_genre_percentile
ORDER BY popularity_percentile ASC;


-- Create author trends VIEW

CREATE VIEW vw_author_trends AS
WITH author_popularity_data AS (
    SELECT
        a.first_name + ' ' + a.last_name AS author_name,
        ROUND(AVG(m.score), 2) AS avg_score,
        AVG(m.members) AS avg_members,
        AVG(m.favorites) AS avg_favorites,
		SUM(m.score*2 + m.members * 1 + m.favorites * 3) AS popularity_score
    FROM normalized_authors AS a
    LEFT JOIN normalized_manga AS m 
    ON m.manga_id = a.manga_id
    WHERE m.favorites IS NOT NULL AND m.members IS NOT NULL
	GROUP BY a.first_name, a.last_name, a.author_id
),

author_ranked_data AS (
    SELECT *,
           DENSE_RANK() OVER(ORDER BY popularity_score DESC) AS popularity_rank
    FROM author_popularity_data
),

with_author_percentile AS (
    SELECT *,
    1.0 * (popularity_rank - 1) / COUNT(*) OVER() AS popularity_percentile
    FROM author_ranked_data
)

SELECT * 
FROM with_author_percentile
