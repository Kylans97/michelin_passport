-- PREPARED -- NOT APPLIED.
--
-- Phone numbers for MICHELIN-starred restaurants in Belgium and Luxembourg,
-- written 2026-10-28. Input: production export of every BE/LU restaurant
-- with michelin_stars set and phone null (132 rows, all open).
--
-- 117 numbers (107 BE, 10 LU), all `confirmed`: from the restaurant's
-- own website, checked against name, city and address (and against its
-- MICHELIN page wherever that loaded); source_url per row in
-- be_lu_phones_all.csv. 15 rows left out on purpose -- see
-- BE_LU_PHONES_REPORT.md. Stored in the human-readable international format
-- restaurants.phone uses.
--
-- Fills only empty values (`phone is null`) -- never overwrites. One
-- transaction; aborts if any code is unknown or in the wrong country.

begin;

create temp table _belu_phones (code text primary key, phone text, country_code text) on commit drop;
insert into _belu_phones values
    ('rest_0154', '+32 3 283 40 40', 'BE'),
    ('rest_0160', '+32 56 19 01 21', 'BE'),
    ('rest_0165', '+32 9 383 58 48', 'BE'),
    ('rest_0170', '+32 2 582 89 92', 'BE'),
    ('rest_0795', '+32 3 233 45 49', 'BE'),
    ('rest_0800', '+32 3 284 28 13', 'BE'),
    ('rest_0805', '+32 14 73 61 25', 'BE'),
    ('rest_0810', '+32 52 39 75 57', 'BE'),
    ('rest_0815', '+32 467 09 11 27', 'BE'),
    ('rest_0820', '+32 9 330 04 86', 'BE'),
    ('rest_0825', '+32 476 30 30 48', 'BE'),
    ('rest_0835', '+32 85 25 55 55', 'BE'),
    ('rest_0845', '+32 12 74 16 74', 'BE'),
    ('rest_0850', '+32 89 57 28 60', 'BE'),
    ('rest_0855', '+32 11 41 38 13', 'BE'),
    ('rest_0860', '+32 2 425 73 60', 'BE'),
    ('rest_0865', '+32 2 644 69 14', 'BE'),
    ('rest_0870', '+32 64 33 66 01', 'BE'),
    ('rest_0875', '+32 80 22 80 27', 'BE'),
    ('rest_0880', '+32 81 20 10 23', 'BE'),
    ('rest_0885', '+32 2 384 83 18', 'BE'),
    ('rest_0155', '+32 51 62 64 62', 'BE'),
    ('rest_0161', '+32 15 63 42 65', 'BE'),
    ('rest_0166', '+32 470 43 74 73', 'BE'),
    ('rest_0171', '+32 14 72 29 05', 'BE'),
    ('rest_0796', '+32 3 230 16 38', 'BE'),
    ('rest_0801', '+32 3 298 86 88', 'BE'),
    ('rest_0806', '+32 15 25 34 40', 'BE'),
    ('rest_0811', '+32 50 68 77 88', 'BE'),
    ('rest_0816', '+32 3 337 09 43', 'BE'),
    ('rest_0821', '+32 3 744 11 40', 'BE'),
    ('rest_0826', '+32 58 51 72 49', 'BE'),
    ('rest_0831', '+32 488 25 74 84', 'BE'),
    ('rest_0836', '+32 2 593 10 01', 'BE'),
    ('rest_0841', '+32 56 49 85 92', 'BE'),
    ('rest_0851', '+32 11 49 67 47', 'BE'),
    ('rest_0856', '+32 16 35 54 74', 'BE'),
    ('rest_0861', '+32 2 771 58 60', 'BE'),
    ('rest_0866', '+32 65 56 86 32', 'BE'),
    ('rest_0871', '+32 85 51 20 14', 'BE'),
    ('rest_0876', '+32 81 60 09 88', 'BE'),
    ('rest_0881', '+32 81 56 86 16', 'BE'),
    ('rest_0886', '+32 2 366 10 51', 'BE'),
    ('rest_0891', '+32 470 89 57 12', 'BE'),
    ('rest_0156', '+32 2 503 00 00', 'BE'),
    ('rest_0162', '+32 9 279 99 77', 'BE'),
    ('rest_0172', '+32 81 41 11 51', 'BE'),
    ('rest_0797', '+32 3 369 26 36', 'BE'),
    ('rest_0802', '+32 3 233 62 70', 'BE'),
    ('rest_0807', '+32 14 70 84 51', 'BE'),
    ('rest_0812', '+32 57 20 06 22', 'BE'),
    ('rest_0817', '+32 9 384 56 52', 'BE'),
    ('rest_0822', '+32 3 778 08 45', 'BE'),
    ('rest_0827', '+32 50 37 16 76', 'BE'),
    ('rest_0832', '+32 50 67 83 10', 'BE'),
    ('rest_0837', '+32 3 808 44 65', 'BE'),
    ('rest_0842', '+32 468 00 66 99', 'BE'),
    ('rest_0847', '+32 89 35 58 28', 'BE'),
    ('rest_0852', '+32 11 26 26 47', 'BE'),
    ('rest_0857', '+32 2 880 74 31', 'BE'),
    ('rest_0867', '+32 496 75 36 79', 'BE'),
    ('rest_0877', '+32 479 06 49 14', 'BE'),
    ('rest_0887', '+32 10 76 00 78', 'BE'),
    ('rest_0892', '+32 84 32 17 92', 'BE'),
    ('rest_0157', '+32 2 374 54 16', 'BE'),
    ('rest_0168', '+32 89 85 48 88', 'BE'),
    ('rest_0173', '+32 65 61 31 70', 'BE'),
    ('rest_0803', '+32 15 63 52 66', 'BE'),
    ('rest_0808', '+32 499 32 73 38', 'BE'),
    ('rest_0813', '+32 15 63 68 61', 'BE'),
    ('rest_0818', '+32 52 44 45 00', 'BE'),
    ('rest_0823', '+32 475 29 75 58', 'BE'),
    ('rest_0828', '+32 59 46 84 00', 'BE'),
    ('rest_0833', '+32 50 60 60 69', 'BE'),
    ('rest_0838', '+32 2 512 29 21', 'BE'),
    ('rest_0843', '+32 50 33 82 59', 'BE'),
    ('rest_0848', '+32 12 26 42 77', 'BE'),
    ('rest_0853', '+32 89 36 25 45', 'BE'),
    ('rest_0858', '+32 16 22 47 75', 'BE'),
    ('rest_0863', '+32 474 65 37 06', 'BE'),
    ('rest_0868', '+32 65 22 05 00', 'BE'),
    ('rest_0873', '+32 80 22 80 22', 'BE'),
    ('rest_0878', '+32 81 63 36 64', 'BE'),
    ('rest_0883', '+32 2 332 26 61', 'BE'),
    ('rest_0888', '+32 63 57 70 56', 'BE'),
    ('rest_0893', '+32 61 53 30 64', 'BE'),
    ('rest_0159', '+32 3 269 90 90', 'BE'),
    ('rest_0164', '+32 50 51 75 76', 'BE'),
    ('rest_0169', '+32 50 36 07 67', 'BE'),
    ('rest_0174', '+32 61 23 95 10', 'BE'),
    ('rest_0799', '+32 3 644 16 65', 'BE'),
    ('rest_0804', '+32 14 55 77 86', 'BE'),
    ('rest_0809', '+32 53 77 61 25', 'BE'),
    ('rest_0819', '+32 9 324 43 11', 'BE'),
    ('rest_0824', '+32 50 70 27 62', 'BE'),
    ('rest_0834', '+32 81 81 30 48', 'BE'),
    ('rest_0839', '+32 50 51 49 37', 'BE'),
    ('rest_0844', '+32 496 25 21 23', 'BE'),
    ('rest_0849', '+32 4 381 23 40', 'BE'),
    ('rest_0854', '+32 89 21 60 20', 'BE'),
    ('rest_0859', '+32 16 84 90 07', 'BE'),
    ('rest_0864', '+32 2 648 78 48', 'BE'),
    ('rest_0869', '+32 69 22 16 89', 'BE'),
    ('rest_0874', '+32 4 295 20 98', 'BE'),
    ('rest_0879', '+32 83 22 05 49', 'BE'),
    ('rest_0884', '+32 2 384 15 01', 'BE'),
    ('rest_0889', '+32 86 65 03 33', 'BE'),
    ('rest_0285', '+352 26 35 20 31', 'LU'),
    ('rest_0290', '+352 27 76 92 85', 'LU'),
    ('rest_0286', '+352 23 66 84 11', 'LU'),
    ('rest_0291', '+352 28 99 39 93', 'LU'),
    ('rest_1368', '+352 22 17 44 500', 'LU'),
    ('rest_0287', '+352 37 00 08', 'LU'),
    ('rest_0292', '+352 26 30 50 87', 'LU'),
    ('rest_0288', '+352 26 65 06 60', 'LU'),
    ('rest_0289', '+352 54 69 94', 'LU'),
    ('rest_0294', '+352 27 44 25', 'LU');

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _belu_phones p
   where not exists (select 1 from public.restaurants r
                      where r.restaurant_code = p.code and r.country_code = p.country_code);
  if bad is not null then raise exception 'unknown codes or country mismatch: %', bad; end if;
end $$;

update public.restaurants r set phone = p.phone, updated_at = now()
  from _belu_phones p
 where r.restaurant_code = p.code and r.phone is null;

commit;
