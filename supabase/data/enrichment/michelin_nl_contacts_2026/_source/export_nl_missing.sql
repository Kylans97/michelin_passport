select 'R' t, r.restaurant_code code, r.name, c.name city, r.address, r.status::text status, r.michelin_stars award, r.property_name, r.website_url, r.phone, r.michelin_url from restaurants r left join cities c on c.id=r.city_id where r.country_code='NL' and (nullif(trim(r.website_url),'') is null or nullif(trim(r.phone),'') is null)
union all
select 'H', h.hotel_code, h.name, c.name, h.address, h.status::text, h.michelin_keys, null, h.website_url, h.phone, h.michelin_url from hotels h left join cities c on c.id=h.city_id where h.country_code='NL' and (nullif(trim(h.website_url),'') is null or nullif(trim(h.phone),'') is null)
order by 1,2;
