-- PREPARED -- NOT APPLIED.
--
-- Phone numbers for the World's 50 Best venues already in the catalogue
-- (2025 restaurants, 2025/2026 hotels), written 2026-10-28 from user
-- feedback asking for a phone number on every ranked venue.
--
-- Only rows researched as `confirmed` are here: 69 restaurants, 82 hotels.
-- 27 rows are left out on purpose (unclear or not found) -- see
-- phones_all.csv and W50B_COMPLETION_REPORT.md. Each number comes from the
-- venue's own website, or its own MICHELIN Guide page where the site
-- publishes none or blocked automated access; source_url per row is in
-- phones_all.csv. Stored in the human-readable international format the
-- phone columns use, derived from the researched E.164 value.
--
-- Fills only empty values (`phone is null`) -- never overwrites a number
-- someone has already set. Prerequisite: 20261014130000_add_hotel_phone.sql.
-- One transaction; aborts if any code fails to match a row.

begin;

create temp table _restaurant_phones (code text primary key, phone text) on commit drop;
insert into _restaurant_phones values
    ('rest_0331', '+34 933 48 68 96'),
    ('rest_0134', '+51 1 3135100'),
    ('rest_0296', '+34 946 58 30 42'),
    ('rest_0132', '+52 55 5280 1660'),
    ('rest_0044', '+34 915 70 07 66'),
    ('rest_0297', '+45 31 71 61 61'),
    ('rest_0298', '+66 98 883 1022'),
    ('rest_0299', '+81 3-5222-5810'),
    ('rest_0135', '+51 1 2428575'),
    ('rest_0136', '+54 11 4507-9873'),
    ('rest_0301', '+852 2711 0063'),
    ('rest_0303', '+66 82 979 3950'),
    ('rest_0304', '+33 1 79 35 50 11'),
    ('rest_0305', '+44 20 3583 4660'),
    ('rest_0306', '+39 0365 20019'),
    ('rest_0307', '+66 99 081 1119'),
    ('rest_0308', '+39 0864 69382'),
    ('rest_0137', '+852 2555 2202'),
    ('rest_0309', '+39 0474 646629'),
    ('rest_0310', '+81 3-5785-0799'),
    ('rest_0311', '+66 2 107 2777'),
    ('rest_0138', '+56 2 2953 8893'),
    ('rest_0312', '+34 943 14 00 24'),
    ('rest_0139', '+51 1 2771628'),
    ('rest_0128', '+971 4 242 1666'),
    ('rest_0140', '+55 21 3449-1834'),
    ('rest_0313', '+82 2-515-7306'),
    ('rest_0314', '+66 92 919 9969'),
    ('rest_0315', '+39 049 630303'),
    ('rest_0316', '+39 0173 366167'),
    ('rest_0266', '+43 1 7133168'),
    ('rest_0317', '+34 616 69 63 22'),
    ('rest_0318', '+66 97 293 5549'),
    ('rest_0319', '+81 3-6435-8018'),
    ('rest_0320', '+971 4 258 0510'),
    ('rest_0321', '+46 8 20 85 80'),
    ('rest_0141', '+51 937 220 734'),
    ('rest_0323', '+45 33 25 22 23'),
    ('rest_0324', '+351 21 342 0607'),
    ('rest_0325', '+39 071 65463'),
    ('rest_0326', '+81 6-6222-2010'),
    ('rest_0327', '+33 1 47 05 09 06'),
    ('rest_0328', '+52 55 5533 7804'),
    ('rest_0142', '+46 414 204 00'),
    ('rest_0143', '+57 301 7420389'),
    ('rest_0329', '+44 20 3829 6888'),
    ('rest_0182', '+49 89 23708658'),
    ('rest_0237', '+41 81 632 10 80'),
    ('rest_0532', '+81 3-6455-5433'),
    ('rest_0474', '+45 22 40 80 20'),
    ('rest_0193', '+49 30 25937930'),
    ('rest_0133', '+52 55 5545 4111'),
    ('rest_0842', '+32 468 00 66 99'),
    ('rest_0156', '+32 2 503 00 00'),
    ('rest_0333', '+34 965 78 41 79'),
    ('rest_0424', '+386 5 389 41 20'),
    ('rest_0502', '+81 50-3188-8819'),
    ('rest_0440', '+853 8889 3663'),
    ('rest_0212', '+49 89 36195900'),
    ('rest_0330', '+34 934 10 00 20'),
    ('rest_0190', '+49 30 91496396'),
    ('rest_0736', '+1 707-723-4646'),
    ('rest_0336', '+34 956 85 18 70'),
    ('rest_0356', '+34 943 52 24 55'),
    ('rest_0059', '+1 212-554-1515'),
    ('rest_0003', '+39 059 867 7662'),
    ('rest_0738', '+1 415-440-0460'),
    ('rest_0763', '+1 212-220-5152'),
    ('rest_0071', '+90 212 244 00 16');

create temp table _hotel_phones (code text primary key, phone text) on commit drop;
insert into _hotel_phones values
    ('hotel_719', '+852 3891 8888'),
    ('hotel_755', '+66 2 659 9000'),
    ('hotel_734', '+52 55 4161 4262'),
    ('hotel_721', '+852 3968 1000'),
    ('hotel_195', '+55 21 2548-7070'),
    ('hotel_742', '+212 5 29 80 80 80'),
    ('hotel_704', '+86 10 8592 8888'),
    ('hotel_762', '+44 20 7629 8860'),
    ('hotel_760', '+971 4 540 8888'),
    ('hotel_707', '+33 1 40 28 00 00'),
    ('hotel_708', '+33 1 44 71 16 00'),
    ('hotel_697', '+55 11 3797-0500'),
    ('hotel_688', '+81 3-5224-3333'),
    ('hotel_710', '+33 4 12 05 55 60'),
    ('hotel_731', '+960 660-0304'),
    ('hotel_767', '+44 20 7499 7070'),
    ('hotel_741', '+212 5 24 38 86 00'),
    ('hotel_766', '+44 20 7139 5012'),
    ('hotel_768', '+44 20 7862 5200'),
    ('hotel_737', '+52 984 370 0400'),
    ('hotel_702', '+61 7 3607 5888'),
    ('hotel_193', '+377 98 06 30 00'),
    ('hotel_718', '+852 2522 0111'),
    ('hotel_781', '+1 212-744-4300'),
    ('hotel_736', '+52 624 144 2800'),
    ('hotel_699', '+81 3-5422-1600'),
    ('hotel_643', '+81 75-468-3100'),
    ('hotel_763', '+44 1993 685800'),
    ('hotel_266', '+385 52 808 000'),
    ('hotel_30', '+43 1 514560'),
    ('hotel_728', '+62 361 4792777'),
    ('hotel_751', '+66 2 035 1111'),
    ('hotel_55', '+41 81 837 10 00'),
    ('hotel_689', '+39 089 831148'),
    ('hotel_720', '+852 2920 2888'),
    ('hotel_729', '+62 811-3978-550'),
    ('hotel_709', '+33 4 93 61 39 01'),
    ('hotel_774', '+1 305-381-3333'),
    ('hotel_658', '+81 75-531-1234'),
    ('hotel_753', '+66 2 200 9000'),
    ('hotel_771', '+1 646-459-5302'),
    ('hotel_756', '+66 2 080 0088'),
    ('hotel_452', '+39 080 225 5850'),
    ('hotel_778', '+1 212-744-1600'),
    ('hotel_777', '+1 310-276-2251'),
    ('hotel_470', '+34 910 88 33 33'),
    ('hotel_776', '+1 805-565-1700'),
    ('hotel_701', '+61 2 9918 4355'),
    ('hotel_757', '+66 2 206 6999'),
    ('hotel_540', '+34 917 01 68 88'),
    ('hotel_693', '+39 041 240801'),
    ('hotel_746', '+27 21 483 1000'),
    ('hotel_679', '+81 75-496-1334'),
    ('hotel_779', '+1 212-231-9400'),
    ('hotel_695', '+55 45 2102-7000'),
    ('hotel_780', '+1 212-941-8900'),
    ('hotel_764', '+44 1764 662231'),
    ('hotel_328', '+39 041 270 7333'),
    ('hotel_713', '+33 1 53 67 66 65'),
    ('hotel_338', '+39 075 844362'),
    ('hotel_346', '+39 059 469054'),
    ('hotel_349', '+39 0185 267801'),
    ('hotel_744', '+968 26 735555'),
    ('hotel_730', '+60 4-950 0500'),
    ('hotel_717', '+852 3196 8888'),
    ('hotel_745', '+51 84 582222'),
    ('hotel_743', '+64 7 222 4555'),
    ('hotel_750', '+46 8 20 05 90'),
    ('hotel_724', '+91 89055 51680'),
    ('hotel_343', '+39 089 875066'),
    ('hotel_758', '+90 252 311 24 00'),
    ('hotel_748', '+94 912 233 388'),
    ('hotel_772', '+1 435-675-4100'),
    ('hotel_722', '+91 1465 223 333'),
    ('hotel_575', '+81 6-6941-8888'),
    ('hotel_711', '+33 1 58 36 60 60'),
    ('hotel_320', '+39 089 812080'),
    ('hotel_735', '+52 984 873 4830'),
    ('hotel_635', '+81 3-3582-0111'),
    ('hotel_692', '+81 50-3134-8096'),
    ('hotel_714', '+33 4 93 37 50 00'),
    ('hotel_187', '+65 6377 8888');

do $$
declare bad text;
begin
  select string_agg(p.code, ', ') into bad from _restaurant_phones p
   where not exists (select 1 from public.restaurants r where r.restaurant_code = p.code);
  if bad is not null then raise exception 'unknown restaurant codes: %', bad; end if;
  select string_agg(p.code, ', ') into bad from _hotel_phones p
   where not exists (select 1 from public.hotels h where h.hotel_code = p.code);
  if bad is not null then raise exception 'unknown hotel codes: %', bad; end if;
end $$;

update public.restaurants r set phone = p.phone, updated_at = now()
  from _restaurant_phones p
 where r.restaurant_code = p.code and r.phone is null;

update public.hotels h set phone = p.phone, updated_at = now()
  from _hotel_phones p
 where h.hotel_code = p.code and h.phone is null;

commit;
