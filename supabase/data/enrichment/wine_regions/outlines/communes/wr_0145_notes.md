# Vale do São Francisco (Brazil): drawn, 5 units (whole IBGE municipalities)

## Official basis
- INPI IP list (at 27 Oct 2026): BR402020000021-3, Instituto do Vinho do Vale do São Francisco, IP granted 01/11/2022, for "vinho fino, vinho nobre, espumante natural e vinho moscatel espumante". Delimitation: continuous 25,138 km² whose limit "é constituído pelos limites político-administrativos dos municípios de Lagoa Grande, Petrolina e Santa Maria da Boa Vista (PE) e Casa Nova e Curaçá (BA), incluindo integralmente seus territórios, conforme definidos pelo IBGE". Same text in the INPI ficha técnica (raw/inpi_ficha_ValedoSoFrancisco.pdf).
- So the area is drawn as the five whole municipalities. Not to be confused with IG200701 "Vale do Submédio São Francisco" (table grapes and mango, 125,755 km²).

## Units
- BR_mun_2608750 Lagoa Grande, BR_mun_2611101 Petrolina, BR_mun_2612604 Santa Maria da Boa Vista (PE); BR_mun_2907202 Casa Nova, BR_mun_2909901 Curaçá (BA). Codes confirmed with IBGE localidades API.
- Source: IBGE Malha Municipal 2024, PE_Municipios_2024 and BA_Municipios_2024 shapefiles (SIRGAS 2000 geographic, treated as WGS84), https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/{PE,BA}/. IBGE data are public; attribution to IBGE (licence wording not re-read this session).
- Checks: union area 25,114 km² (sphere) vs INPI 25,138 (0.1%). Embrapa's own GeoInfo layer "Indicação de Procedência de Vinhos Vale do São Francisco - limite" (dataset 12637, published 2026-10-07, built from IBGE 2022) has a symmetric difference of 0.00 km² with the IBGE 2024 union. Petrolina city inside; Juazeiro (BA, not in IP) outside. Simplified 100 m: area change < 0.25% per unit.

## Style (sources)
- Summary: tropical, irrigated, along the São Francisco, semi-arid north east (INPI ficha "vinhos tropicais", irrigation, "clima tropical semiárido"; Embrapa "Vins tropicaux" 2020; SevenFifty Sept 2023 "semi-arid tropical climate"); two crops a year (INPI ficha "duas safras anuais"; Embrapa; SevenFifty "yield twice annually per plant"); sparkling and Moscatel sparkling (INPI product types; Embrapa: c. 70% of c. 4 M litres is sparkling, half of it sweet muscat); Syrah reds and Chenin whites (Embrapa; SevenFifty "potent Syrah and fresh Chenin Blanc").
- Grapes: no planting figures found, so the order is not an area ranking. Syrah heads Embrapa's red list and SevenFifty names it; Chenin Blanc heads Embrapa's still white list and dry sparkling list, SevenFifty names it; Moscato Canelli (Muscat Blanc à Petits Grains; VIVC passport 8193 lists "MOSCATO CANELLI" as a synonym) and Moscato Itália are the sparkling muscat grapes (Embrapa; both in the INPI variety list); Tempranillo (Embrapa reds and rosé; INPI list).
- Red structure: INPI ficha says reds range from light and young to fuller and age-worthy; Embrapa "acidité équilibrée". No consistent two-source profile; null.
- Label note: the INPI ficha gives product types only, no labelling rule; null.
- Pairing: none; null.
