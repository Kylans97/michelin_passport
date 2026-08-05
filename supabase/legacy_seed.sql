-- Table Passport - restaurants seed data
-- Run AFTER 001_initial_schema.sql
-- ON CONFLICT DO NOTHING makes it safe to re-run.

INSERT INTO public.restaurants
  (name, michelin_stars, cuisine, city, country, country_flag, description, price_range)
VALUES
  ('Noma',                           3, 'New Nordic',            'Copenhagen', 'Denmark',        '🇩🇰', 'Reinventing Nordic cuisine through foraging and fermentation.',            '€€€€'),
  ('Geranium',                       3, 'New Nordic',            'Copenhagen', 'Denmark',        '🇩🇰', 'Elevated Nordic tasting menus with panoramic rooftop views.',               '€€€€'),
  ('Mirazur',                        3, 'Contemporary French',   'Menton',     'France',         '🇫🇷', 'Garden-to-table cuisine perched on the French Riviera.',                   '€€€€'),
  ('Alain Ducasse au Plaza Athenee', 3, 'Naturalist French',     'Paris',      'France',         '🇫🇷', 'Iconic Parisian dining room that champions natural ingredients.',           '€€€€'),
  ('Septime',                        1, 'Modern French',         'Paris',      'France',         '🇫🇷', 'Relaxed bistronomy with natural wines in the 11th arrondissement.',         '€€€'),
  ('Osteria Francescana',            3, 'Modern Italian',        'Modena',     'Italy',          '🇮🇹', 'Massimo Bottura''s visionary deconstruction of Italian culinary heritage.', '€€€€'),
  ('Dal Pescatore',                  3, 'Classic Italian',       'Canneto',    'Italy',          '🇮🇹', 'Family-run institution serving timeless Lombard cuisine since 1925.',      '€€€€'),
  ('El Celler de Can Roca',          3, 'Creative Catalan',      'Girona',     'Spain',          '🇪🇸', 'Three Roca brothers weaving emotion, science, and terroir into every dish.','€€€€'),
  ('DiverXO',                        3, 'Asian-Spanish Fusion',  'Madrid',     'Spain',          '🇪🇸', 'David Munoz avant-garde laboratory where East meets West.',                 '€€€€'),
  ('Sushi Yoshitake',                3, 'Edo-mae Sushi',         'Tokyo',      'Japan',          '🇯🇵', 'Intimate eight-seat counter serving the purest Edo-mae omakase.',          '€€€€'),
  ('Narisawa',                       2, 'Innovative Satoyama',   'Tokyo',      'Japan',          '🇯🇵', 'Nature-inspired Japanese cuisine blending forest, mountain, and sea.',      '€€€€'),
  ('Ultraviolet',                    3, 'Psycho Taste',          'Shanghai',   'China',          '🇨🇳', 'A single-table multisensory experience merging food, light, and sound.',    '€€€€'),
  ('Eleven Madison Park',            3, 'Contemporary American', 'New York',   'United States',  '🇺🇸', 'Plant-based fine dining inside a landmark Art Deco dining room.',          '€€€€'),
  ('Le Bernardin',                   3, 'French Seafood',        'New York',   'United States',  '🇺🇸', 'Legendary seafood temple redefining French cuisine in Midtown Manhattan.',  '€€€€'),
  ('Restaurant Gordon Ramsay',       3, 'Classic French',        'London',     'United Kingdom', '🇬🇧', 'Gordon Ramsay Chelsea flagship - a masterclass in classical technique.',    '€€€€')
ON CONFLICT DO NOTHING;
