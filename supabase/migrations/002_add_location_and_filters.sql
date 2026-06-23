-- Table Passport - migration 002
-- Adds coordinates, country code, Michelin URL, category, and validation.
-- Run in: Supabase Dashboard -> SQL Editor -> New query
-- Safe to re-run (uses IF NOT EXISTS / IF EXISTS guards).


-- -------------------------------------------------------------------------
-- 1. New columns on public.restaurants
-- -------------------------------------------------------------------------

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS latitude     DECIMAL(9,6),
  ADD COLUMN IF NOT EXISTS longitude    DECIMAL(9,6),
  ADD COLUMN IF NOT EXISTS country_code TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS michelin_url TEXT,
  ADD COLUMN IF NOT EXISTS website_url  TEXT,
  -- category distinguishes stars / Bib Gourmand / Key hotels later
  ADD COLUMN IF NOT EXISTS category     TEXT NOT NULL DEFAULT 'star';


-- -------------------------------------------------------------------------
-- 2. Validation constraints
-- -------------------------------------------------------------------------

-- Coordinates must be in valid ranges when present
ALTER TABLE public.restaurants
  DROP CONSTRAINT IF EXISTS check_latitude,
  DROP CONSTRAINT IF EXISTS check_longitude,
  DROP CONSTRAINT IF EXISTS check_category,
  DROP CONSTRAINT IF EXISTS check_michelin_stars_extended;

ALTER TABLE public.restaurants
  ADD CONSTRAINT check_latitude  CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
  ADD CONSTRAINT check_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  -- Bib Gourmand uses 0 stars; starred restaurants use 1-3
  ADD CONSTRAINT check_michelin_stars_extended CHECK (michelin_stars BETWEEN 0 AND 3),
  -- Only allow known category values
  ADD CONSTRAINT check_category  CHECK (category IN ('star', 'bib_gourmand', 'key_hotel', 'selected'));


-- -------------------------------------------------------------------------
-- 3. Unique constraint to block duplicate restaurants
--    Uses name + city because two restaurants with the same name in the
--    same city is essentially impossible at Michelin level.
-- -------------------------------------------------------------------------

ALTER TABLE public.restaurants
  DROP CONSTRAINT IF EXISTS restaurants_name_city_unique;

ALTER TABLE public.restaurants
  ADD CONSTRAINT restaurants_name_city_unique UNIQUE (name, city);


-- -------------------------------------------------------------------------
-- 4. Back-fill country_code for any rows already in the table
-- -------------------------------------------------------------------------

UPDATE public.restaurants SET country_code = 'DK' WHERE country = 'Denmark'       AND country_code = '';
UPDATE public.restaurants SET country_code = 'FR' WHERE country = 'France'         AND country_code = '';
UPDATE public.restaurants SET country_code = 'IT' WHERE country = 'Italy'          AND country_code = '';
UPDATE public.restaurants SET country_code = 'ES' WHERE country = 'Spain'          AND country_code = '';
UPDATE public.restaurants SET country_code = 'JP' WHERE country = 'Japan'          AND country_code = '';
UPDATE public.restaurants SET country_code = 'CN' WHERE country = 'China'          AND country_code = '';
UPDATE public.restaurants SET country_code = 'US' WHERE country = 'United States'  AND country_code = '';
UPDATE public.restaurants SET country_code = 'GB' WHERE country = 'United Kingdom' AND country_code = '';
UPDATE public.restaurants SET country_code = 'NL' WHERE country = 'Netherlands'    AND country_code = '';
UPDATE public.restaurants SET country_code = 'BE' WHERE country = 'Belgium'        AND country_code = '';


-- -------------------------------------------------------------------------
-- 5. Index on country_code and michelin_stars for fast filter queries
-- -------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_restaurants_country_code   ON public.restaurants (country_code);
CREATE INDEX IF NOT EXISTS idx_restaurants_michelin_stars ON public.restaurants (michelin_stars);
CREATE INDEX IF NOT EXISTS idx_restaurants_category       ON public.restaurants (category);
