-- Ordered stops for 25 of the 38 journey routes, from
-- journey_route_stops_20261120.csv (same folder, which carries the source
-- URL, coordinate source and verification note of every row).
--
-- Written 2026-11-20. NOT APPLIED. Prepared for the product owner's
-- approval. Needs journey_route_stops_countries_prereq.sql first (RO, BG,
-- BA). The 13 routes held back are listed in
-- journey_route_stops_HELD_BACK.md and get no rows.
--
-- Stops come only from each operator's own published itinerary; the
-- train or ship's start, the places it stops at, and its end, in order.
-- Coordinates are the named station, or the town where the operator
-- names no station (the note says which). Matched on route_code, never on
-- a name. Refuses to run if a route_code does not resolve or a route
-- already has stops, so it can never mix with or duplicate rows.

begin;

create temp table _stops (
  route_code   text,
  stop_order   smallint,
  place        text,
  country_code char(2),
  latitude     double precision,
  longitude    double precision
) on commit drop;

insert into _stops values
  ('train_001_r01', 1, 'Paris Gare de l''Est', 'FR', 48.8769, 2.3592),
  ('train_001_r01', 2, 'Venezia Santa Lucia', 'IT', 45.4408, 12.3208),
  ('train_001_r02', 1, 'Venezia Santa Lucia', 'IT', 45.4408, 12.3208),
  ('train_001_r02', 2, 'Paris Gare de l''Est', 'FR', 48.8769, 2.3592),
  ('train_001_r03', 1, 'Brussels-South (Bruxelles-Midi)', 'BE', 50.8352, 4.3352),
  ('train_001_r03', 2, 'Venezia Santa Lucia', 'IT', 45.4408, 12.3208),
  ('train_001_r04', 1, 'Paris Gare de l''Est', 'FR', 48.8769, 2.3592),
  ('train_001_r04', 2, 'Firenze Santa Maria Novella', 'IT', 43.7761, 11.2481),
  ('train_001_r05', 1, 'Paris Gare de l''Est', 'FR', 48.8769, 2.3592),
  ('train_001_r05', 2, 'Wien Westbahnhof', 'AT', 48.1967, 16.3378),
  ('train_001_r06', 1, 'Istanbul Sirkeci', 'TR', 41.015, 28.9772),
  ('train_001_r06', 2, 'Bucharest', 'RO', 44.4325, 26.1039),
  ('train_001_r06', 3, 'Sinaia railway station', 'RO', 45.3527, 25.5529),
  ('train_001_r06', 4, 'Budapest', 'HU', 47.4925, 19.0514),
  ('train_001_r06', 5, 'Paris Gare de l''Est', 'FR', 48.8769, 2.3592),
  ('train_002_r01', 1, 'Cusco', 'PE', -13.5254, -71.9712),
  ('train_002_r01', 2, 'Puno', 'PE', -15.8357, -70.0264),
  ('train_002_r01', 3, 'Saracocha', 'PE', -15.7811, -70.6223),
  ('train_002_r01', 4, 'Arequipa', 'PE', -16.4101, -71.5415),
  ('train_003_r02', 1, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r02', 2, 'Boat of Garten', 'GB', 57.2481, -3.7526),
  ('train_003_r02', 3, 'Carrbridge', 'GB', 57.2794, -3.828),
  ('train_003_r02', 4, 'Dundee', 'GB', 56.4566, -2.971),
  ('train_003_r02', 5, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r03', 1, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r03', 2, 'Spean Bridge', 'GB', 56.8899, -4.9215),
  ('train_003_r03', 3, 'Arisaig', 'GB', 56.913, -5.8395),
  ('train_003_r03', 4, 'Bridge of Orchy', 'GB', 56.5162, -4.7642),
  ('train_003_r03', 5, 'Wemyss Bay', 'GB', 55.8769, -4.8891),
  ('train_003_r03', 6, 'Kilmarnock', 'GB', 55.6124, -4.4992),
  ('train_003_r03', 7, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r05', 1, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r05', 2, 'Keith', 'GB', 57.5514, -2.9542),
  ('train_003_r05', 3, 'Tain', 'GB', 57.8144, -4.0519),
  ('train_003_r05', 4, 'Kyle of Lochalsh', 'GB', 57.28, -5.7138),
  ('train_003_r05', 5, 'Carrbridge', 'GB', 57.2794, -3.828),
  ('train_003_r05', 6, 'Boat of Garten', 'GB', 57.2481, -3.7526),
  ('train_003_r05', 7, 'Kingussie', 'GB', 57.0776, -4.0543),
  ('train_003_r05', 8, 'Perth', 'GB', 56.3916, -3.4384),
  ('train_003_r05', 9, 'Dundee', 'GB', 56.4566, -2.971),
  ('train_003_r05', 10, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r06', 1, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_003_r06', 2, 'Montrose', 'GB', 56.7129, -2.4722),
  ('train_003_r06', 3, 'Invergordon', 'GB', 57.6891, -4.1745),
  ('train_003_r06', 4, 'Kyle of Lochalsh', 'GB', 57.28, -5.7138),
  ('train_003_r06', 5, 'Boat of Garten', 'GB', 57.2481, -3.7526),
  ('train_003_r06', 6, 'Kingussie', 'GB', 57.0776, -4.0543),
  ('train_003_r06', 7, 'Dundee', 'GB', 56.4566, -2.971),
  ('train_003_r06', 8, 'Edinburgh', 'GB', 55.9521, -3.1893),
  ('train_004_r01', 1, 'Singapore (Woodlands Station)', 'SG', 1.4439, 103.7692),
  ('train_004_r01', 2, 'Gemas', 'MY', 2.5797, 102.6137),
  ('train_004_r01', 3, 'Butterworth', 'MY', 5.3933, 100.3664),
  ('train_004_r01', 4, 'Ipoh', 'MY', 4.5972, 101.0733),
  ('train_004_r01', 5, 'Singapore (Woodlands Station)', 'SG', 1.4439, 103.7692),
  ('train_004_r02', 1, 'Singapore (Woodlands Station)', 'SG', 1.4439, 103.7692),
  ('train_004_r02', 2, 'Gemas', 'MY', 2.5797, 102.6137),
  ('train_004_r02', 3, 'Merapoh', 'MY', 4.6931, 102.0028),
  ('train_004_r02', 4, 'Butterworth', 'MY', 5.3933, 100.3664),
  ('train_004_r02', 5, 'Ipoh', 'MY', 4.5972, 101.0733),
  ('train_004_r02', 6, 'Singapore (Woodlands Station)', 'SG', 1.4439, 103.7692),
  ('train_005_r01', 1, 'London Victoria', 'GB', 51.4952, -0.1441),
  ('train_005_r01', 2, 'Grange-over-Sands', 'GB', 54.1958, -2.9025),
  ('train_005_r01', 3, 'Princes Risborough', 'GB', 51.718, -0.844),
  ('train_005_r01', 4, 'London Victoria', 'GB', 51.4952, -0.1441),
  ('train_005_r02', 1, 'London Victoria', 'GB', 51.4952, -0.1441),
  ('train_005_r02', 2, 'St Erth', 'GB', 50.1714, -5.4437),
  ('train_005_r02', 3, 'Bruton', 'GB', 51.1117, -2.4473),
  ('train_005_r02', 4, 'London Victoria', 'GB', 51.4952, -0.1441),
  ('train_006_r01', 1, 'Roma Ostiense', 'IT', 41.8727, 12.4845),
  ('train_006_r01', 2, 'Venice', 'IT', 45.4375, 12.3358),
  ('train_006_r01', 3, 'Budapest', 'HU', 47.4925, 19.0514),
  ('train_006_r01', 4, 'Brașov', 'RO', 45.6667, 25.6167),
  ('train_006_r01', 5, 'Istanbul', 'TR', 41.0136, 28.955),
  ('train_007_r01', 1, 'Paris', 'FR', 48.8567, 2.3522),
  ('train_007_r01', 2, 'Vienna', 'AT', 48.2083, 16.3725),
  ('train_007_r01', 3, 'Postojna', 'SI', 45.7759, 14.2137),
  ('train_007_r01', 4, 'Belgrade', 'RS', 44.8178, 20.4569),
  ('train_007_r01', 5, 'Sofia', 'BG', 42.7, 23.33),
  ('train_007_r01', 6, 'Istanbul', 'TR', 41.0136, 28.955),
  ('train_007_r02', 1, 'Istanbul Sirkeci', 'TR', 41.015, 28.9772),
  ('train_007_r02', 2, 'Sofia', 'BG', 42.7, 23.33),
  ('train_007_r02', 3, 'Belgrade', 'RS', 44.8178, 20.4569),
  ('train_007_r02', 4, 'Postojna', 'SI', 45.7759, 14.2137),
  ('train_007_r02', 5, 'Vienna', 'AT', 48.2083, 16.3725),
  ('train_007_r02', 6, 'Paris', 'FR', 48.8567, 2.3522),
  ('train_007_r03', 1, 'Venice', 'IT', 45.4375, 12.3358),
  ('train_007_r03', 2, 'Trieste', 'IT', 45.6503, 13.7703),
  ('train_007_r03', 3, 'Postojna', 'SI', 45.7759, 14.2137),
  ('train_007_r03', 4, 'Pula', 'HR', 44.8703, 13.8456),
  ('train_007_r03', 5, 'Rijeka', 'HR', 45.3272, 14.4411),
  ('train_007_r03', 6, 'Sarajevo', 'BA', 43.8564, 18.4131),
  ('train_007_r03', 7, 'Mostar', 'BA', 43.3436, 17.8075),
  ('train_007_r03', 8, 'Belgrade', 'RS', 44.8178, 20.4569),
  ('train_007_r03', 9, 'Sofia', 'BG', 42.7, 23.33),
  ('train_007_r03', 10, 'Plovdiv', 'BG', 42.15, 24.75),
  ('train_007_r03', 11, 'Istanbul', 'TR', 41.0136, 28.955),
  ('train_008_r01', 1, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_008_r01', 2, 'Jaipur', 'IN', 26.915, 75.82),
  ('train_008_r01', 3, 'Sawai Madhopur', 'IN', 26.0, 76.35),
  ('train_008_r01', 4, 'Fatehpur Sikri', 'IN', 27.091, 77.661),
  ('train_008_r01', 5, 'Agra', 'IN', 27.18, 78.02),
  ('train_008_r01', 6, 'Orchha', 'IN', 25.35, 78.64),
  ('train_008_r01', 7, 'Khajuraho', 'IN', 24.85, 79.925),
  ('train_008_r01', 8, 'Varanasi', 'IN', 25.3189, 83.0128),
  ('train_008_r01', 9, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_008_r02', 1, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_008_r02', 2, 'Jaipur', 'IN', 26.915, 75.82),
  ('train_008_r02', 3, 'Sawai Madhopur', 'IN', 26.0, 76.35),
  ('train_008_r02', 4, 'Agra', 'IN', 27.18, 78.02),
  ('train_008_r02', 5, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_008_r03', 1, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_008_r03', 2, 'Agra', 'IN', 27.18, 78.02),
  ('train_008_r03', 3, 'Sawai Madhopur', 'IN', 26.0, 76.35),
  ('train_008_r03', 4, 'Jaipur', 'IN', 26.915, 75.82),
  ('train_008_r03', 5, 'Bikaner', 'IN', 28.0167, 73.3119),
  ('train_008_r03', 6, 'Jodhpur', 'IN', 26.28, 73.02),
  ('train_008_r03', 7, 'Udaipur', 'IN', 24.58, 73.68),
  ('train_008_r03', 8, 'Mumbai Chhatrapati Shivaji Maharaj Terminus (CSMT)', 'IN', 18.9399, 72.8354),
  ('train_008_r04', 1, 'Mumbai Chhatrapati Shivaji Maharaj Terminus (CSMT)', 'IN', 18.9399, 72.8354),
  ('train_008_r04', 2, 'Udaipur', 'IN', 24.58, 73.68),
  ('train_008_r04', 3, 'Jodhpur', 'IN', 26.28, 73.02),
  ('train_008_r04', 4, 'Deshnok', 'IN', 27.791, 73.341),
  ('train_008_r04', 5, 'Bikaner', 'IN', 28.0167, 73.3119),
  ('train_008_r04', 6, 'Jaipur', 'IN', 26.915, 75.82),
  ('train_008_r04', 7, 'Sawai Madhopur', 'IN', 26.0, 76.35),
  ('train_008_r04', 8, 'Fatehpur Sikri', 'IN', 27.091, 77.661),
  ('train_008_r04', 9, 'Agra', 'IN', 27.18, 78.02),
  ('train_008_r04', 10, 'Delhi Safdarjung railway station', 'IN', 28.5824, 77.1859),
  ('train_009_r01', 1, 'Kyoto Station', 'JP', 34.9856, 135.7586),
  ('train_009_r01', 2, 'Shimonoseki Station', 'JP', 33.9504, 130.9231),
  ('train_009_r02', 1, 'Shimonoseki Station', 'JP', 33.9504, 130.9231),
  ('train_009_r02', 2, 'Kyoto Station', 'JP', 34.9856, 135.7586);

do $$
begin
  if exists (
    select 1 from _stops s
    left join public.journey_routes r on r.route_code = s.route_code
    where r.id is null
  ) then
    raise exception 'A route_code in this file does not exist';
  end if;
  if exists (
    select 1 from public.journey_route_stops t
    join public.journey_routes r on r.id = t.route_id
    where r.route_code in (select route_code from _stops)
  ) then
    raise exception 'A route in this file already has stops';
  end if;
end;
$$;

insert into public.journey_route_stops
  (route_id, stop_order, place, country_code, latitude, longitude)
select r.id, s.stop_order, s.place, s.country_code, s.latitude, s.longitude
from _stops s
join public.journey_routes r on r.route_code = s.route_code;

commit;
