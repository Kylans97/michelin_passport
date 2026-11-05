# Fictional content behind site/lookbook.html, for a LOCAL Supabase stack only.
# Prints SQL; usage: python3 seed_lookbook.py <local test user id> | psql <local db>
# Never run this against production: it inserts invented venues, awards and members.
# Names were checked by web search on 2026-11-04. Photos: Unsplash, free licence.
import sys
uid=sys.argv[1]
ph=lambda i:f"https://images.unsplash.com/photo-{i}?w=1400&q=80&auto=format&fit=crop"
P={k:ph(v) for k,v in dict(
 d_salmon='1689672235501-6dc1e56d454c',d_fish='1676471926534-d5c9771909fa',d_wine='1750943036999-81e666b2296c',d_dessert='1703849133132-98c23595b981',d_art='1616671285410-2a676a9a433d',d_shell='1464093515883-ec948246accb',
 i_wood='1766832255363-c9f060ade8b0',i_dim='1653259038915-7cf0b7a4dd6c',i_bright='1776993298456-98c71c0e177e',i_room='1744776411221-702f2848b0b2',i_booth='1776993298456-98c71c0e177e',i_green='1643101570532-88c8ecc07c1f',
 h_villa='1780491250090-16aa696f83eb',h_room='1611892440504-42a792e24d32',h_lobby='1782890790046-2aefb0b503cb',h_facade='1791273624377-76e93edc2af9',h_bed='1618773928121-c32242e63f39',h_garden='1761971976519-7e27a35c9c49',
 e_long='1641834954859-5f211db537e6',e_flowers='1731045970795-82a17ec99f30',e_amber='1783818412534-370b60b8a1d8',e_roof='1752766074168-44afdbaaf390',w_cellar='1765850258613-9e671f59a9ad',w_barrels='1534655882117-f9eff36a1574').items()}
c={'ams':'c0000000-0000-0000-0000-000000000001','rot':'c0000000-0000-0000-0000-000000000002','ant':'c0000000-0000-0000-0000-000000000003'}
R=[('a1','LB-1','Maison Aurelle','ams','NL',2,'michelin_star','Prinsengracht 1','4.884 52.372',['i_wood','d_salmon','d_shell','d_art'],
 "A quiet room on the canal, twelve tables, and a menu that changes when the market does. Chef Lena Verhoeven cooks with North Sea fish, vegetables from a single farm in Flevoland and the patience of a kitchen that still makes everything itself. The wine list is long on grower Champagne and white Burgundy, and our sommelier is happy to pour something you have never heard of."),
 ('a2','LB-2','Noordtij','rot','NL',1,'michelin_star','Maasboulevard 12','4.488 51.915',['i_dim','d_fish','d_wine'],
 "From our windows you watch the ships go by while the kitchen works with what the same water brings in. Tasting menus only, in five or eight courses, with a pairing built around small producers along the Rhine and the Moselle."),
 ('a3','LB-3','Atelier Verano','ant','BE',1,'michelin_star','Kloosterstraat 40','4.396 51.216',['i_bright','d_art','d_dessert'],
 "A former print workshop turned open kitchen. Eight seats at the counter and twenty in the room, with a menu led by fire and fermentation."),
 ('a4','LB-4','Casa Lumera','ams','NL',None,'editorial_selection','Czaar Peterstraat 8','4.925 52.367',['i_room','d_dessert'],
 "A neighbourhood table with serious ambitions: handmade pasta, a wood oven and a cellar of Italian natural wines."),]
H=[('b1','LBH-1','Hotel Belmare','ams','NL',2,'Herengracht 200','4.889 52.369',['h_villa','h_room','h_lobby'],
 "Forty rooms in a converted merchant's house, with a garden no one expects to find behind the canal. Maison Aurelle is our restaurant, and breakfast comes from its kitchen too."),
 ('b2','LBH-2','The Alderwick','ant','BE',1,'Meir 75','4.409 51.218',['h_facade','h_bed','h_garden'],
 "A grand nineteenth-century facade with quiet, modern rooms behind it. Walk to the cathedral, the diamond quarter and half of the city's best tables."),]
E=[('e1','Four hands: Maison Aurelle × Noordtij','dinner','2026-12-05','19:00','Amsterdam','NL','Europe/Amsterdam','e_long',"Two kitchens, one evening. Lena Verhoeven and Noordtij's Bas de Wit cook seven courses together, passing plates across a single pass. Wine pairing by both sommeliers.",[('r','a1',True,True),('r','a2',True,False)],['four-hands','guest-chef','wine'],'available','paid','From €295 per person, wine pairing included'),
 ('e2','Winemaker dinner with a Mosel grower','dinner','2027-01-23','19:30','Rotterdam','NL','Europe/Amsterdam','w_cellar',"Six Rieslings from one steep slope, poured by the woman who farms it, with a menu Noordtij writes around them.",[('r','a2',True,True)],['winemaker','wine'],'available','paid','€185 per person'),
 ('e3','Winter gala at Hotel Belmare','gala','2027-02-13','18:30','Amsterdam','NL','Europe/Amsterdam','e_amber',"Black tie in the garden room: Champagne, five courses from Maison Aurelle and a live quartet. Proceeds go to a culinary school for young people.",[('h','b1',True,True),('r','a1',False,False)],['charity'],'available','paid','€350 per person'),
 ('e4','Spring tasting on the roof','tasting','2027-04-10','16:00','Antwerp','BE','Europe/Brussels','e_roof',"Twelve small plates and twelve wines on the roof of The Alderwick, with Atelier Verano at the fire.",[('h','b2',True,True),('r','a3',True,False)],['wine','guest-chef'],'available','paid','€120 per person'),
 ('e5','Game dinner by the fire','dinner','2026-11-28','19:00','Antwerp','BE','Europe/Brussels','e_flowers',"The season's last game, cooked over embers at one long table.",[('r','a3',True,True)],['wild-game'],'sold_out','paid',None),]
u=lambda s:{'a':'aaaaaaaa','b':'bbbbbbbb','e':'eeeeeeee'}[s[0]]+'-0000-0000-0000-00000000000'+s[1]
q=lambda s:'NULL' if s is None else "'"+s.replace("'","''")+"'"
o=["\\set ON_ERROR_STOP 1","begin;","set session_replication_role=replica;",
"insert into public.cities(id,country_code,name) values "+",".join(f"('{c['ams']}','NL','Amsterdam'),('{c['rot']}','NL','Rotterdam'),('{c['ant']}','BE','Antwerp')".split('@'))+" on conflict do nothing;",
"insert into public.cuisines(id,name,family_id) overriding system value values (901,'Modern European',4),(902,'Seafood',4),(903,'Creative',4),(904,'Italian',4) on conflict do nothing;",
f"update public.profiles set username='alexvdb',display_name='Alex van den Berg',has_seen_welcome=true,home_country_code='NL',is_discoverable=true where id='{uid}';",
f"insert into public.profiles(id,username,display_name,has_seen_welcome) values('{uid}','alexvdb','Alex van den Berg',true) on conflict(id) do update set username='alexvdb',display_name='Alex van den Berg',has_seen_welcome=true;"]
for i,(n,d) in enumerate([('sophiek','Sophie Kramer'),('thomasr','Thomas Roos'),('emmadj','Emma de Jong'),('noorv','Noor Vermeulen'),('maartenb','Maarten Bos')],1):
    m=f"00000000-0000-0000-0000-0000000000f{i}"
    o.append(f"insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values('{m}','00000000-0000-0000-0000-000000000000','authenticated','authenticated','m{i}@example.test','x',now(),now(),now(),'{{}}','{{}}') on conflict do nothing;")
    o.append(f"insert into public.profiles(id,username,display_name,has_seen_welcome) values('{m}','{n}','{d}',true) on conflict(id) do update set display_name=excluded.display_name;")
    o.append(f"insert into public.friendships(requester_id,addressee_id,status) values('{uid}','{m}','accepted') on conflict do nothing;")
cu={'a1':901,'a2':902,'a3':903,'a4':904}
for k,code,n,ci,cc,st,inc,ad,ll,ph_,ab in R:
    o.append(f"insert into public.restaurants(id,restaurant_code,name,michelin_stars,inclusion_reason,city_id,country_code,address,location,website_url,booking_url,phone,status) values('{u(k)}','{code}',{q(n)},{st if st else 'NULL'},'{inc}','{c[ci]}','{cc}',{q(ad)},'POINT({ll})','https://example.com','https://example.com','+31 20 000 0000','open');")
    for j,p in enumerate(ph_): o.append(f"insert into public.restaurant_photos(restaurant_id,image_url,alt_text,display_order) values('{u(k)}','{P[p]}','Photo of {n.replace(chr(39),'')}',{j});")
    o.append(f"insert into public.venue_about_submissions(user_id,venue_type,venue_id,about_text,status,reviewed_at) values('{uid}','restaurant','{u(k)}',{q(ab)},'approved',now());")
    o.append(f"insert into public.restaurant_cuisines(restaurant_id,cuisine_id,position,source,source_url,source_label,verified_on) values('{u(k)}',{cu[k]},1,'legacy','https://example.com','local','2026-11-04');")
    for wd in range(2,7):
        o.append(f"insert into public.restaurant_opening_hours(restaurant_id,weekday,slot,opens_at,closes_at) values('{u(k)}',{wd},1,'18:30','22:30');")
    if st: o.append(f"insert into public.award_history(entity_type,entity_id,guide_year,award_type,award_value,is_current) values('restaurant','{u(k)}',2026,'michelin_stars',{st},true) on conflict do nothing;")
    else: o.append(f"insert into public.editorial_selections(restaurant_id,selected_on) values('{u(k)}','2026-10-28');")
for k,code,n,ci,cc,ke,ad,ll,ph_,ab in H:
    o.append(f"insert into public.hotels(id,hotel_code,name,michelin_keys,city_id,country_code,address,location,website_url,booking_url,phone,status) values('{u(k)}','{code}',{q(n)},{ke},'{c[ci]}','{cc}',{q(ad)},'POINT({ll})','https://example.com','https://example.com','+31 20 000 0000','open');")
    for j,p in enumerate(ph_): o.append(f"insert into public.hotel_photos(hotel_id,image_url,alt_text,display_order) values('{u(k)}','{P[p]}','Photo of {n}',{j});")
    o.append(f"insert into public.venue_about_submissions(user_id,venue_type,venue_id,about_text,status,reviewed_at) values('{uid}','hotel','{u(k)}',{q(ab)},'approved',now());")
    o.append(f"insert into public.award_history(entity_type,entity_id,guide_year,award_type,award_value,is_current) values('hotel','{u(k)}',2026,'michelin_keys',{ke},true) on conflict do nothing;")
o.append(f"insert into public.hotel_restaurants(hotel_id,restaurant_id,link_confidence) values('{u('b1')}','{u('a1')}','exact') on conflict do nothing;")
for rid,role,name,bio in [('a1','chef','Lena Verhoeven','Trained in Lyon and Copenhagen, and back in Amsterdam since 2019.'),('a1','sommelier','Daan Hofman','Grower Champagne, white Burgundy and the occasional surprise.'),('a2','chef','Bas de Wit','Grew up on the Maas and has cooked its fish for twenty years.')]:
    o.append(f"insert into public.venue_team_submissions(user_id,venue_type,venue_id,role,name,bio,status,reviewed_at) values('{uid}','restaurant','{u(rid)}','{role}',{q(name)},{q(bio)},'approved',now());")
for k,n,t,d,tm,ci,cc,tz,img,de,links,tags,av,ad,note in E:
    o.append(f"insert into public.events(id,name,description,event_type,start_date,end_date,start_time,country_code,city,timezone,image_url,moderation_status,status,availability_status,admission_type,admission_note,ticket_url,official_url) values('{u(k)}',{q(n)},{q(de)},'{t}','{d}','{d}','{tm}','{cc}','{ci}','{tz}','{P[img]}','published','upcoming','{av}','{ad}',{q(note)},'https://example.com','https://example.com');")
    for ty,lid,host,venue in links:
        tb='event_restaurants' if ty=='r' else 'event_hotels'; col='restaurant_id' if ty=='r' else 'hotel_id'
        o.append(f"insert into public.{tb}(event_id,{col},is_host,is_venue,approved_at) values('{u(k)}','{u(lid)}',{host},{venue},now());")
    for s in tags:
        o.append(f"insert into public.event_tag_assignments(event_id,tag_id) select '{u(k)}',id from public.event_tags where slug='{s}';")
for i,st in [(1,'going'),(2,'going'),(3,'interested')]:
    o.append(f"insert into public.event_attendance(event_id,user_id,status,visibility) values('{u('e1')}','00000000-0000-0000-0000-0000000000f{i}','{st}','friends');")
o.append(f"insert into public.event_attendance(event_id,user_id,status,visibility) values('{u('e1')}','{uid}','going','friends');")
o.append("set session_replication_role=origin;")
V=[(uid,'restaurant','a1','2026-09-12',9,9,9,8,8,2),(uid,'restaurant','a2','2026-07-04',9,8,None,9,7,1),(uid,'restaurant','a3','2026-05-16',8,9,7,None,8,1),(uid,'restaurant','a4','2026-03-02',8,8,8,9,9,None)]
for m in range(1,6):
    mm=f"00000000-0000-0000-0000-0000000000f{m}"
    V+= [(mm,'restaurant','a1','2026-08-1'+str(m),9,9,8+(m%2),8,8,2),(mm,'restaurant','a2','2026-06-1'+str(m),8,9,8,9,7,1),(mm,'restaurant','a3','2026-04-1'+str(m),9,8,8,7+(m%2),8,1)]
for us,ty,e,d,fo,se,wi,at,va,st in V:
    n=lambda x:'NULL' if x is None else x
    o.append(f"insert into public.visits(user_id,entity_type,entity_id,visited_on,food_rating,service_rating,wine_rating,atmosphere_rating,value_rating,stars_at_visit,visibility) values('{us}','{ty}','{u(e)}','{d}',{n(fo)},{n(se)},{n(wi)},{n(at)},{n(va)},{n(st)},'friends');")
for us in [uid]+[f"00000000-0000-0000-0000-0000000000f{m}" for m in range(1,6)]:
    o.append(f"insert into public.visits(user_id,entity_type,entity_id,visited_on,service_rating,room_rating,experience_rating,value_rating,keys_at_visit,visibility) values('{us}','hotel','{u('b1')}','2026-09-11',9,9,9,8,2,'friends');")
o.append(f"insert into public.news_articles(id,title,body,image_url,status,published_at,section) values('cccccccc-1000-0000-0000-000000000001','Why we built this',{q('Some evenings are worth crossing the world for. Mantelier is a place to find them, plan them and keep them.')},'{P['i_green']}','published',now()-interval '20 days','about'),('cccccccc-1000-0000-0000-000000000002','At the table with Lena Verhoeven',{q('Lena Verhoeven on markets, patience and the one dish she will never take off the menu.'+chr(10)+chr(10)+'Q: Where does a menu start?'+chr(10)+chr(10)+'At the market, on a Tuesday, usually with something I had not planned on buying.'+chr(10)+chr(10)+'> A menu is a promise you can keep for about six weeks.')},'{P['d_salmon']}','published',now()-interval '3 days','interview'),('cccccccc-1000-0000-0000-000000000003','Four hands, one pass',{q('What happens when two kitchens share one evening.')},'{P['e_long']}','published',now()-interval '6 days','story');")
o.append(f"insert into public.planned_trips(id,user_id,title,start_date,end_date,country_code,city) values('dddddddd-0000-0000-0000-000000000001','{uid}','A weekend in Amsterdam','2026-12-04','2026-12-07','NL','Amsterdam');")
o.append(f"insert into public.planned_venues(user_id,entity_type,entity_id,trip_id,start_date) values('{uid}','hotel','{u('b1')}','dddddddd-0000-0000-0000-000000000001','2026-12-04'),('{uid}','restaurant','{u('a1')}','dddddddd-0000-0000-0000-000000000001','2026-12-05');")
o.append(f"update public.planned_trip_destinations set city_id='{c['ams']}' where trip_id='dddddddd-0000-0000-0000-000000000001';")
o.append("commit;")
print("\n".join(o))
