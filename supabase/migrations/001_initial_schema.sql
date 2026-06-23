-- Table Passport - initial schema
-- Run in: Supabase Dashboard -> SQL Editor -> New query
-- Safe to run multiple times (idempotent).


-- -------------------------------------------------------------------------
-- 1. Tables
-- -------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.restaurants (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT         NOT NULL,
  michelin_stars INTEGER      NOT NULL CHECK (michelin_stars BETWEEN 1 AND 3),
  cuisine        TEXT         NOT NULL,
  city           TEXT         NOT NULL,
  country        TEXT         NOT NULL,
  country_flag   TEXT         NOT NULL DEFAULT '',
  description    TEXT         NOT NULL DEFAULT '',
  price_range    TEXT         NOT NULL DEFAULT '$$$$',
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT,
  email         TEXT,
  tier          TEXT         NOT NULL DEFAULT 'Explorer',
  member_since  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.visited_restaurants (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id   UUID          NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  visited_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  notes           TEXT,
  personal_rating DECIMAL(3,1)  CHECK (personal_rating BETWEEN 0 AND 10),
  UNIQUE(user_id, restaurant_id)
);

CREATE TABLE IF NOT EXISTS public.wishlist (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id  UUID         NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  added_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, restaurant_id)
);


-- -------------------------------------------------------------------------
-- 2. Row Level Security
-- -------------------------------------------------------------------------

ALTER TABLE public.restaurants         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visited_restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist            ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first so the script is safe to re-run
DROP POLICY IF EXISTS "restaurants_select"   ON public.restaurants;
DROP POLICY IF EXISTS "profiles_select"      ON public.profiles;
DROP POLICY IF EXISTS "profiles_update"      ON public.profiles;
DROP POLICY IF EXISTS "visited_select"       ON public.visited_restaurants;
DROP POLICY IF EXISTS "visited_insert"       ON public.visited_restaurants;
DROP POLICY IF EXISTS "visited_delete"       ON public.visited_restaurants;
DROP POLICY IF EXISTS "wishlist_select"      ON public.wishlist;
DROP POLICY IF EXISTS "wishlist_insert"      ON public.wishlist;
DROP POLICY IF EXISTS "wishlist_delete"      ON public.wishlist;

-- restaurants: any authenticated user can read
CREATE POLICY "restaurants_select"
  ON public.restaurants
  FOR SELECT TO authenticated
  USING (true);

-- profiles: users can only read / update their own row
CREATE POLICY "profiles_select"
  ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "profiles_update"
  ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id);

-- visited_restaurants: users manage only their own rows
CREATE POLICY "visited_select"
  ON public.visited_restaurants
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "visited_insert"
  ON public.visited_restaurants
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "visited_delete"
  ON public.visited_restaurants
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- wishlist: users manage only their own rows
CREATE POLICY "wishlist_select"
  ON public.wishlist
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "wishlist_insert"
  ON public.wishlist
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wishlist_delete"
  ON public.wishlist
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);


-- -------------------------------------------------------------------------
-- 3. Auto-create profile on sign-up
--    Fires after every new row in auth.users (every registration).
-- -------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
