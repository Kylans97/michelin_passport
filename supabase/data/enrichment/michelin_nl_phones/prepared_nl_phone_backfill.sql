-- PREPARED -- NOT APPLIED.
--
-- Phone numbers for MICHELIN-starred restaurants in the Netherlands,
-- written 2026-10-28. Input: production export of every NL restaurant with
-- michelin_stars set and phone null (117 rows); the 2 marked
-- permanently_closed (Spectrum, De Groene Lantaarn) were skipped.
--
-- 100 numbers, all `confirmed`: from the restaurant's own website (or the
-- site of the hotel/estate it sits in, where the restaurant itself publishes
-- that number), checked against city and address; source_url per row in
-- nl_phones_all.csv. 15 rows left out on purpose (unclear: only a
-- hotel/estate switchboard; not found) -- see NL_PHONES_REPORT.md.
-- Stored in the human-readable international format restaurants.phone uses.
--
-- Fills only empty values (`phone is null`) -- never overwrites. One
-- transaction; aborts if any code does not exist or is not a Dutch row.

begin;

create temp table _nl_phones (code text primary key, phone text) on commit drop;
insert into _nl_phones values
    ('rest_0001', '+31 20 345 1763'),
    ('rest_0011', '+31 43 321 2359'),
    ('rest_0016', '+31 20 218 2182'),
    ('rest_0021', '+31 70 387 2081'),
    ('rest_0025', '+31 20 678 7450'),
    ('rest_0029', '+31 475 465 979'),
    ('rest_0033', '+31 20 462 4562'),
    ('rest_0037', '+31 38 853 0000'),
    ('rest_0041', '+31 40 221 5593'),
    ('rest_0048', '+31 10 212 0110'),
    ('rest_0052', '+31 10 710 8034'),
    ('rest_0057', '+31 20 214 9729'),
    ('rest_0065', '+31 495 452 028'),
    ('rest_0070', '+31 73 203 4888'),
    ('rest_0075', '+31 413 786 352'),
    ('rest_0083', '+31 23 542 7270'),
    ('rest_0087', '+31 43 450 4490'),
    ('rest_0091', '+31 20 280 0816'),
    ('rest_0095', '+31 20 496 1943'),
    ('rest_0100', '+31 117 381 223'),
    ('rest_0105', '+31 316 268 808'),
    ('rest_0109', '+31 43 350 0405'),
    ('rest_0118', '+31 20 236 6522'),
    ('rest_0122', '+31 20 765 1212'),
    ('rest_0152', '+31 55 203 4140'),
    ('rest_0783', '+31 20 799 5000'),
    ('rest_0787', '+31 50 409 4531'),
    ('rest_0792', '+31 183 554 000'),
    ('rest_0005', '+31 13 203 2004'),
    ('rest_0012', '+31 43 321 3364'),
    ('rest_0017', '+31 38 792 0110'),
    ('rest_0022', '+31 43 325 1359'),
    ('rest_0026', '+31 113 853 535'),
    ('rest_0030', '+31 23 526 3600'),
    ('rest_0034', '+31 317 313 118'),
    ('rest_0038', '+31 521 361 444'),
    ('rest_0049', '+31 40 200 5955'),
    ('rest_0054', '+31 527 291 833'),
    ('rest_0066', '+31 23 512 3910'),
    ('rest_0072', '+31 50 700 1370'),
    ('rest_0076', '+31 475 600 262'),
    ('rest_0084', '+31 165 850 809'),
    ('rest_0088', '+31 15 204 9114'),
    ('rest_0096', '+31 6 51231074'),
    ('rest_0101', '+31 6 46027252'),
    ('rest_0106', '+31 294 233 201'),
    ('rest_0110', '+31 40 226 3232'),
    ('rest_0119', '+31 20 678 8300'),
    ('rest_0123', '+31 162 450 806'),
    ('rest_0153', '+31 53 720 0820'),
    ('rest_0784', '+31 72 509 3644'),
    ('rest_0793', '+31 71 515 6898'),
    ('rest_0007', '+31 10 720 0802'),
    ('rest_0013', '+31 20 237 4790'),
    ('rest_0018', '+31 43 204 1056'),
    ('rest_0023', '+31 23 529 3173'),
    ('rest_0027', '+31 43 240 0040'),
    ('rest_0035', '+31 117 348 696'),
    ('rest_0039', '+31 294 232 326'),
    ('rest_0046', '+31 10 425 0520'),
    ('rest_0050', '+31 50 204 1235'),
    ('rest_0063', '+31 343 593 366'),
    ('rest_0068', '+31 13 536 5805'),
    ('rest_0073', '+31 15 206 1456'),
    ('rest_0081', '+31 10 227 1922'),
    ('rest_0085', '+31 20 334 8685'),
    ('rest_0089', '+31 348 414 040'),
    ('rest_0093', '+31 20 674 7555'),
    ('rest_0103', '+31 294 234 848'),
    ('rest_0107', '+31 10 430 2333'),
    ('rest_0111', '+31 174 725 505'),
    ('rest_0120', '+31 40 211 7700'),
    ('rest_0146', '+31 341 415 848'),
    ('rest_0780', '+31 341 415 290'),
    ('rest_0785', '+31 71 365 1304'),
    ('rest_0794', '+31 222 319 623'),
    ('rest_0009', '+31 251 676 760'),
    ('rest_0014', '+31 20 238 6985'),
    ('rest_0019', '+31 70 345 5866'),
    ('rest_0024', '+31 20 210 3090'),
    ('rest_0032', '+31 20 247 1007'),
    ('rest_0036', '+31 45 575 0226'),
    ('rest_0040', '+31 24 322 5093'),
    ('rest_0047', '+31 20 531 1619'),
    ('rest_0051', '+31 113 381 753'),
    ('rest_0056', '+31 343 512 920'),
    ('rest_0064', '+31 30 200 6767'),
    ('rest_0069', '+31 20 638 0866'),
    ('rest_0074', '+31 165 383 249'),
    ('rest_0082', '+31 182 355 750'),
    ('rest_0090', '+31 30 272 2207'),
    ('rest_0094', '+31 481 421 308'),
    ('rest_0099', '+31 20 682 7290'),
    ('rest_0104', '+31 70 307 7970'),
    ('rest_0108', '+31 20 554 9454'),
    ('rest_0113', '+31 486 851 565'),
    ('rest_0117', '+31 40 244 6666'),
    ('rest_0121', '+31 10 436 5049'),
    ('rest_0150', '+31 543 472 951'),
    ('rest_0786', '+31 561 728 729');

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _nl_phones p
   where not exists (select 1 from public.restaurants r
                      where r.restaurant_code = p.code and r.country_code = 'NL');
  if bad is not null then raise exception 'unknown or non-NL restaurant codes: %', bad; end if;
end $$;

update public.restaurants r set phone = p.phone, updated_at = now()
  from _nl_phones p
 where r.restaurant_code = p.code and r.phone is null;

commit;
