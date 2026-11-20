-- The World's 50 Best Vineyards 2026: 44 estates into public.vineyards and
-- their 2026 ranks into public.worlds_50_best_vineyards.
--
-- Generated 2026-11-20 from worlds_50_best_vineyards_2026.csv (this folder)
-- on the product owner's go-ahead that day. Only rows with
-- verification_status verified or partial are included; the 6 held_back
-- rows (vine_0015, vine_0021, vine_0028, vine_0033, vine_0047, vine_0048;
-- QA-520..QA-522) stay out. location only where the estate itself publishes
-- a pin or coordinates; NULL otherwise, never geocoded.
--
-- Needs 20261101550000_add_vineyards.sql and 20261101560000_add_lb_uy_countries.sql.
-- Refuses (nothing written) if any of these codes already exists, and checks
-- the counts before committing.
--
-- Run: supabase db query --linked --file supabase/data/enrichment/worlds_50_best_vineyards/prepared_worlds_50_best_vineyards_2026.sql

begin;

do $$
begin
  if exists (select 1 from public.vineyards where vineyard_code like 'vine_%') then
    raise exception 'vineyards already holds vine_ codes; refusing to insert twice';
  end if;
end;
$$;

with src (vineyard_code, name, country_code, region, city, address, location, website_url, rank, source_url) as (
  values
  ('vine_0001', 'Schloss Johannisberg', 'DE', 'Rheingau', 'Geisenheim', 'Schloss Johannisberg, 65366 Geisenheim-Johannisberg', st_setsrid(st_makepoint(7.9837394, 49.9999818), 4326)::geography, 'https://schloss-johannisberg.de/', 1, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/schloss-johannisberg.html'),
  ('vine_0002', 'Bodegas Ysios', 'ES', 'Rioja', 'Laguardia', 'Camino de La Hoya s/n, 01300 Laguardia - Álava, Spain', null, 'https://bodegasysios.com/en/', 2, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/Bodegas-Ysios.html'),
  ('vine_0003', 'Montes', 'CL', 'Colchagua Valley', 'Santa Cruz', 'Bodega de Apalta, Parcela 15 - Millahue de Apalta, Santa Cruz, Chile', null, 'https://www.monteswines.com/', 3, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/montes.html'),
  ('vine_0004', 'Maison Ruinart', 'FR', 'Champagne', 'Reims', '4 rue des Crayères, Reims, France', null, 'https://www.ruinart.com/en-uk', 4, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/maison-ruinart.html'),
  ('vine_0005', 'Creation', 'ZA', 'Hemel-en-Aarde', 'Hermanus', 'Hemel-en-Aarde Road, Hermanus 7200, South Africa', null, 'https://www.creationwines.com/', 5, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/creation.html'),
  ('vine_0006', 'Clos Apalta', 'CL', 'Colchagua Valley', null, 'Apalta KM 5, Apalta Valley, Colchagua, Chile', st_setsrid(st_makepoint(-71.291969, -34.5927294), 4326)::geography, 'https://www.closapalta.com/', 6, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/Clos-Apalta.html'),
  ('vine_0007', 'Klein Constantia', 'ZA', 'Western Cape Province', 'Constantia', 'Klein Constantia Road (estate entrance at the end of the road), Constantia; postal: PO Box 375, Constantia, 7848', st_setsrid(st_makepoint(18.4129167, -34.0386111), 4326)::geography, 'https://www.kleinconstantia.com/', 7, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/klein-constantia.html'),
  ('vine_0008', 'Château Smith Haut Lafitte', 'FR', 'Bordeaux', 'Martillac', 'Château Smith Haut Lafitte, 33650 Bordeaux Martillac, France', st_setsrid(st_makepoint(-0.558248, 44.7326094), 4326)::geography, 'https://www.smith-haut-lafitte.com/en/home/', 8, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/chateau-smith-haut-lafitte.html'),
  ('vine_0009', 'Château D''Yquem', 'FR', 'Sauternes', 'Sauternes', 'Château d''Yquem, 33210 Sauternes, France', st_setsrid(st_makepoint(-0.3281159, 44.5436001), 4326)::geography, 'http://yquem.fr/int-en/', 9, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/chateau-dyquem.html'),
  ('vine_0010', 'Durigutti Family Winemakers', 'AR', 'Mendoza', 'Luján de Cuyo', 'Pasaje La Reta S/N, Las Compuertas, Luján de Cuyo, Mendoza', st_setsrid(st_makepoint(-68.9502697, -33.0248598), 4326)::geography, 'https://durigutti.com/', 10, 'https://www.the50.com/vineyards/best-in-the-world/the-list/1-10/Durigutti-Family-Winemakers.html'),
  ('vine_0011', 'Champagne Taittinger', 'FR', 'Champagne', 'Reims', '9, place Saint-Nicaise - CS 10011 - 51722 Reims Cedex, France', null, 'https://www.taittinger.com/', 11, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/Champagne-Taittinger.html'),
  ('vine_0012', 'Pago De Carraovejas', 'ES', 'Ribera del Duero', 'Peñafiel', 'Camino de Carraovejas, s/n, 47300 Peñafiel, Valladolid, España', st_setsrid(st_makepoint(-4.087881, 41.594799), 4326)::geography, 'http://www.pagodecarraovejas.com', 12, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/Pago-De-Carraovejas.html'),
  ('vine_0013', 'Casas del Bosque', 'CL', 'Casablanca Valley', 'Casablanca', 'Hijuela Nº 2 Ex Fundo Santa Rosa, Casablanca, Chile', st_setsrid(st_makepoint(-71.4349889, -33.3174912), 4326)::geography, 'https://www.casasdelbosque.cl/', 13, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/vina-casas-del-bosque.html'),
  ('vine_0014', 'Château Pape Clément', 'FR', 'Bordeaux', 'Pessac', '216 avenue Dr Nancel Pénard, 33600 Pessac, France', st_setsrid(st_makepoint(-0.6440558, 44.8053852), 4326)::geography, 'https://en.chateau-pape-clement.fr/', 14, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/chateau-pape-clement.html'),
  ('vine_0016', 'Quinta do Crasto', 'PT', 'Douro Valley', 'Sabrosa', 'Quinta do Crasto, Gouvinhas, 5060-063 Sabrosa, Portugal', st_setsrid(st_makepoint(-7.628309, 41.165037), 4326)::geography, 'https://www.quintadocrasto.wine/en/', 16, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/Quinta-do-Crasto.html'),
  ('vine_0017', 'Vasse Felix', 'AU', 'Margaret River', 'Cowaramup', 'Caves Road (Cnr Tom Cullity Drive), Cowaramup, Margaret River, WA 6284, Australia', null, 'https://www.vassefelix.com.au/', 17, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/Vasse-Felix.html'),
  ('vine_0018', 'Château Kefraya', 'LB', 'Bekaa Valley', null, null, null, 'https://www.chateaukefraya.com/', 18, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/Ch%C3%A2teau-Kefraya.html'),
  ('vine_0019', 'Viu Manent', 'CL', 'Colchagua Valley', 'Cunaco', 'Carretera del Vino Km 37, Cunaco, VI Región, Chile', st_setsrid(st_makepoint(-71.3100159, -34.6513564), 4326)::geography, 'https://viumanent.cl/en/', 19, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/viu-manent.html'),
  ('vine_0020', 'Bodega Garzón', 'UY', 'Maldonado', 'Garzón', 'Ruta 9 km. 175 - Garzón, Maldonado, Uruguay', st_setsrid(st_makepoint(-54.6289692, -34.5697479), 4326)::geography, 'https://www.bodegagarzon.com/', 20, 'https://www.the50.com/vineyards/best-in-the-world/the-list/11-20/bodega-garzon.html'),
  ('vine_0022', 'Ceretto', 'IT', 'Piedmont', 'Alba', 'Strada Provinciale Alba/Barolo, Località San Cassiano, 34, 12051 Alba (CN), Italy', st_setsrid(st_makepoint(7.9962875, 44.6722487), 4326)::geography, 'https://www.ceretto.com/it', 22, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/ceretto.html'),
  ('vine_0023', 'Concha y Toro', 'CL', 'Maipo Valley', 'Pirque', 'Av. Virginia Subercaseaux 210, Pirque, Región Metropolitana, Chile', st_setsrid(st_makepoint(-70.5765944, -33.6356005), 4326)::geography, 'https://conchaytoro.com/en/', 23, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/Concha-y-Toro.html'),
  ('vine_0024', 'Gusbourne', 'GB', 'Kent', 'Appledore', 'Kenardington Road, Appledore, Ashford, Kent, TN26 2BE, United Kingdom', st_setsrid(st_makepoint(0.7971409, 51.0469246), 4326)::geography, 'https://www.gusbourne.com/', 24, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/Gusbourne.html'),
  ('vine_0025', 'Bodegas Muga', 'ES', 'Rioja', 'Haro', 'Avda. Vizcaya, 2, Barrio de la Estación, 26200 Haro, La Rioja, Spain', null, 'https://www.bodegasmuga.com/en/', 25, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/Bodegas-Muga.html'),
  ('vine_0026', 'Perelada', 'ES', 'Empordà', 'Peralada', 'Paraje la Granja, s/n, 17491 Peralada, Girona, Spain', null, 'https://perelada.com/', 26, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/Perelada.html'),
  ('vine_0027', 'Jordan Vineyard & Winery', 'US', 'Alexander Valley', 'Healdsburg', '1474 Alexander Valley Road, Healdsburg, CA 95448-9003, USA', st_setsrid(st_makepoint(-122.8437964, 38.656218), 4326)::geography, 'https://www.jordanwinery.com/', 27, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/jordan-vineyard-and-winery.html'),
  ('vine_0029', 'William Chris Vineyards', 'US', 'Texas Hill Country', 'Hye', '10352 US Highway 290, Hye, TX 78635, USA', null, 'https://williamchriswines.com', 29, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/William-Chris-Vineyards.html'),
  ('vine_0030', 'Szepsy Pince', 'HU', 'Tokaj', null, null, null, 'https://szepsy.hu/', 30, 'https://www.the50.com/vineyards/best-in-the-world/the-list/21-30/Szepsy-Pince.html'),
  ('vine_0031', 'Cloudy Bay Vineyards', 'NZ', 'Marlborough', null, null, null, 'http://www.cloudybay.com', 31, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Cloudy-Bay-Vineyards.html'),
  ('vine_0032', 'Riccitelli Wine Company', 'AR', 'Mendoza', 'Luján de Cuyo', 'Las Compuertas, Luján de Cuyo, Mendoza, Argentina (no street address published)', null, 'https://matiasriccitelli.com/en/winery/', 32, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Riccitelli-Wine-Company.html'),
  ('vine_0034', 'Shafer Vineyards', 'US', 'Napa Valley', 'Napa', '6154 Silverado Trail, Napa, CA 94558, USA', null, 'https://shafervineyards.com/', 34, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Shafer-Vineyards.html'),
  ('vine_0035', 'Viña Cobos', 'AR', 'Mendoza', 'Luján de Cuyo', 'Costa Flores y Ruta 7, Agrelo, Luján de Cuyo, Mendoza, Argentina', null, 'https://vinacobos.com/', 35, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/vina-cobos.html'),
  ('vine_0036', 'M. Chapoutier', 'FR', 'Rhône Valley', 'Tain l''Hermitage', '18 avenue du Docteur Paul Durand, 26600 Tain l''Hermitage, France', null, 'https://www.chapoutier.com/en/', 36, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/M-Chapoutier.html'),
  ('vine_0037', 'Champagne Bollinger', 'FR', 'Champagne', 'Aÿ', '20 Boulevard Maréchal de Lattre, 51160 Aÿ, France', null, 'https://www.champagne-bollinger.com/', 37, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Champagne-Bollinger.html'),
  ('vine_0038', 'Aperture Cellars', 'US', 'Sonoma', 'Healdsburg', '12291 Old Redwood Highway, Healdsburg, CA 95448, USA', null, 'https://aperture-cellars.com/', 38, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Aperture-Cellars.html'),
  ('vine_0039', 'Craggy Range', 'NZ', 'Hawke’s Bay', 'Havelock North', '253 Waimarama Road, Havelock North, Hawke''s Bay 4294, New Zealand', st_setsrid(st_makepoint(176.923042, -39.6928384), 4326)::geography, 'https://craggyrange.com/', 39, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/Craggy-Range.html'),
  ('vine_0040', 'Marqués de Murrieta', 'ES', 'Rioja', 'Logroño', 'N-232a Km 402, 26006 Logroño, La Rioja, Spain', st_setsrid(st_makepoint(-2.381978, 42.4579426), 4326)::geography, 'https://marquesdemurrieta.com/', 40, 'https://www.the50.com/vineyards/best-in-the-world/the-list/31-40/marques-de-murrieta-estate.html'),
  ('vine_0041', 'Leeuwin Estate', 'AU', 'Margaret River', 'Margaret River', 'Stevens Road, Margaret River, WA 6285, Australia', null, 'https://leeuwinestate.com.au/', 41, 'https://www.the50.com/vineyards/best-in-the-world/the-list/Leeuwin-Estate.html'),
  ('vine_0042', 'Château Pichon Baron', 'FR', 'Bordeaux', 'Pauillac', 'Château Pichon Baron, 33250 Pauillac, France', st_setsrid(st_makepoint(-0.7516086, 45.1770493), 4326)::geography, 'https://www.pichonbaron.com/en/', 42, 'https://www.the50.com/vineyards/best-in-the-world/the-list/Ch%C3%A2teau-Pichon-Baron.html'),
  ('vine_0043', 'Delaire Graff Estate', 'ZA', 'Stellenbosch', 'Stellenbosch', 'Helshoogte Rd, Stellenbosch, 7602, South Africa', st_setsrid(st_makepoint(18.919449, -33.920723), 4326)::geography, 'https://www.delaire.co.za/', 43, 'https://www.the50.com/vineyards/best-in-the-world/the-list/Delaire-Graff-Estate.html'),
  ('vine_0044', 'Vivanco', 'ES', 'Rioja', 'Briones', 'Carretera Nacional 232, 26330 Briones, La Rioja, España', st_setsrid(st_makepoint(-2.7764055, 42.5393224), 4326)::geography, 'https://vivancoculturadevino.es/es/', 44, 'https://www.the50.com/vineyards/best-in-the-world/the-list/bodegas-vivanco.html'),
  ('vine_0045', 'Seppeltsfield', 'AU', 'Barossa Valley', 'Seppeltsfield', '730 Seppeltsfield Road, Seppeltsfield, Barossa Valley SA 5355, Australia', null, 'https://seppeltsfield.com.au/', 45, 'https://www.the50.com/vineyards/best-in-the-world/the-list/Seppeltsfield.html'),
  ('vine_0046', 'Tokara Wine Estate', 'ZA', 'Stellenbosch', 'Stellenbosch', 'Helshoogte Pass, at the gateway to the Banghoek Valley, Stellenbosch, South Africa (no street address published)', st_setsrid(st_makepoint(18.9187235, -33.9180637), 4326)::geography, 'https://www.tokara.com/', 46, 'https://www.the50.com/vineyards/best-in-the-world/the-list/Tokara-Wine-Estate.html'),
  ('vine_0049', 'Gramona', 'ES', 'Alt Penedès', 'Sant Sadurní d''Anoia', 'Carrer Indústria 36, 08770 Sant Sadurní d''Anoia, Spain', st_setsrid(st_makepoint(1.7863346, 41.4232548), 4326)::geography, 'https://gramona.com/en/', 49, 'https://www.the50.com/vineyards/best-in-the-world/the-list/gramona.html'),
  ('vine_0050', 'Bodega Colomé', 'AR', 'Salta', 'Molinos', 'Road 53, Km 20, Molinos (4419), Salta, Argentina', null, 'https://www.bodegacolome.com/', 50, 'https://www.the50.com/vineyards/best-in-the-world/the-list/bodega-colome.html')
), ins as (
  insert into public.vineyards (vineyard_code, name, country_code, region, city, address, location, website_url)
  select vineyard_code, name, country_code, region, city, address, location, website_url from src
  returning id, vineyard_code
)
insert into public.worlds_50_best_vineyards (vineyard_id, year, rank, list_type, source_url, announced_on)
select ins.id, 2026, src.rank, 'top_50', src.source_url, date '2026-11-18'
from ins join src using (vineyard_code);

do $$
declare v int; w int;
begin
  select count(*) into v from public.vineyards;
  select count(*) into w from public.worlds_50_best_vineyards where year = 2026;
  if v <> 44 or w <> 44 then
    raise exception 'expected 44 vineyards and 44 ranks, got % and %', v, w;
  end if;
end;
$$;

commit;
