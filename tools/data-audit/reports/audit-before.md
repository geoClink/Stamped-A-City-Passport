# BuildingRegistry.json audit

140 cities, 1392 landmarks, 338 findings.

| Check | Count |
|---|---|
| wrong_country_or_sign | 7 |
| far_from_city | 59 |
| placeholder_coordinates | 126 |
| city_centre_mismatch | 1 |
| stacked_pins | 62 |
| implausible_year | 5 |
| empty_text | 1 |
| suspicious_size | 11 |
| height_unknown | 65 |
| too_few_landmarks | 1 |

## wrong_country_or_sign (7)

- **Dubai** `dxb_index_tower` The Index — 12278.5 km from the city centre
- **Brasília** `br_alvorada_palace` Palácio da Alvorada — 9528.0 km from the city centre
- **Brasília** `br_national_museum` National Museum of the Republic — 14452.5 km from the city centre
- **Brasília** `br_sanctuary_dom_bosco` Sanctuary of Don Bosco — 10528.0 km from the city centre
- **Brasília** `br_national_theater` Cláudio Santoro National Theater — 8993.5 km from the city centre
- **Brasília** `br_pontao_lago_sul` Pontão do Lago Sul — 10833.9 km from the city centre
- **Brasília** `br_national_library` National Library of Brasília — 14452.5 km from the city centre

## far_from_city (59)

- **Denver** `den-06` United States Air Force Academy Cadet Chapel — 81.6 km from the city centre
- **Denver** `den-12` Denver International Airport (Jeppesen Terminal) — 28.9 km from the city centre
- **Pittsburgh** `pit-04` Fallingwater — 72.7 km from the city centre
- **Victoria** `vic-08` Hatley Castle — 26.2 km from the city centre
- **Beijing** `pek_daxing_airport` Beijing Daxing International — 51.0 km from the city centre
- **Abu Dhabi** `auh_louvre_abudhabi` Louvre Abu Dhabi — 96.1 km from the city centre
- **Abu Dhabi** `auh_emirates_palace` Emirates Palace — 96.1 km from the city centre
- **Abu Dhabi** `auh_abrahamic_family_house` Abrahamic Family House — 96.1 km from the city centre
- **Abu Dhabi** `auh_guggenheim` Guggenheim Abu Dhabi (Upcoming) — 96.1 km from the city centre
- **Mumbai** `bom_cst` Chhatrapati Shivaji Terminus — 49.4 km from the city centre
- **Mumbai** `bom_municipal` BMC Headquarters — 49.4 km from the city centre
- **Shanghai** `sha_intercontinental` InterContinental Shanghai Wonderland — 31.1 km from the city centre
- **Cairo** `cai_tower` Cairo Tower — 361.8 km from the city centre
- **Cairo** `cai_muhammad_ali` Mosque of Muhammad Ali — 361.8 km from the city centre
- **Cairo** `cai_mogamma` The Mogamma — 361.8 km from the city centre
- **Cairo** `cai_st_virgin_mary` The Hanging Church — 361.8 km from the city centre
- **Cairo** `cai_opera_house` Cairo Opera House — 361.8 km from the city centre
- **Cairo** `cai_iconic_tower` Iconic Tower — 43.5 km from the city centre
- **Cairo** `cai_apple_tradeline_cfc` Apple (Tradeline - Cairo Festival City) — 361.8 km from the city centre
- **Cairo** `cai_abdeen_palace` Abdeen Palace — 361.8 km from the city centre
- **Cairo** `cai_mosque_madrasa_sultan_hassan` Mosque-Madrasa of Sultan Hassan — 361.8 km from the city centre
- **Cairo** `cai_egyptian_museum_tahrir` Museum of Egyptian Antiquities (The Red Museum) — 361.8 km from the city centre
- **Sydney** `syd_st_marys` St Mary's Cathedral — 43.6 km from the city centre
- **Mexico City** `mex_bellas_artes` Palacio de Bellas Artes — 496.3 km from the city centre
- **Mexico City** `mex_postal_palace` Palacio de Correos de México — 496.3 km from the city centre
- **Houston** `hou-11` NASA Johnson Space Center (Building 30) — 35.7 km from the city centre
- **Phoenix** `phx-01` Taliesin West — 27.7 km from the city centre
- **Riyadh** `ruh-01` Kingdom Centre — 217.6 km from the city centre
- **Riyadh** `ruh-03` Al Faisaliah Center — 217.6 km from the city centre
- **Riyadh** `ruh-04` King Abdulaziz Center for World Culture (Ithra) — 384.2 km from the city centre
- **Riyadh** `ruh-08` At-Turaif District (Diriyah) — 177.2 km from the city centre
- **Riyadh** `ruh-apple-roshn` Apple ROSHN Front — 217.6 km from the city centre
- **Bali** `bali-tanah-lot` Pura Tanah Lot — 29.1 km from the city centre
- **Bali** `bali-besakih` Pura Besakih (Mother Temple) — 28.7 km from the city centre
- **Bali** `bali-tirta-gangga` Tirta Gangga Water Palace — 29.1 km from the city centre
- **Bali** `bali-green-school` The Green School (Heart of School) — 29.1 km from the city centre
- **Bali** `bali-gwk-statue` Garuda Wisnu Kencana (GWK Statue) — 29.1 km from the city centre
- **Bali** `bali-ulun-danu` Pura Ulun Danu Beratan — 29.1 km from the city centre
- **Bali** `bali-uluwatu` Pura Luhur Uluwatu — 29.1 km from the city centre
- **Bali** `bali-ubud-palace` Ubud Royal Palace (Puri Saren Agung) — 29.1 km from the city centre
- **Bali** `bali-potato-head` Potato Head Studios (Desa Potato Head) — 29.1 km from the city centre
- **Bali** `bali-sharma-springs` Sharma Springs — 29.1 km from the city centre
- **Campinas** `cpq-mercado-municipal` Mercado Municipal — 81.1 km from the city centre
- **Campinas** `cpq-metropolitan-cathedral` Catedral Metropolitana — 53.5 km from the city centre
- **Marrakech** `koutoubia-mosque` Koutoubia Mosque — 138.1 km from the city centre
- **São Paulo** `br_copan` Edifício Copan — 128.9 km from the city centre
- **São Paulo** `br_altino_arantes` Farol Santander (Altino Arantes Building) — 213.6 km from the city centre
- **São Paulo** `br_theatre_municipal` Theatro Municipal de São Paulo — 213.6 km from the city centre
- **São Paulo** `br_cathedral_se` São Paulo Cathedral (Catedral da Sé) — 75.5 km from the city centre
- **São Paulo** `br_mosteiro_sao_bento` Saint Benedict Monastery — 30.8 km from the city centre
- **São Paulo** `br_mercadao` Municipal Market of São Paulo — 37.7 km from the city centre
- **Ho Chi Minh City** `hcmc-cu-chi-tunnels` Cu Chi tunnels — 39.9 km from the city centre
- **Xi'an** `cn_terracotta_army` Terracotta Army — 35.0 km from the city centre
- **Chengdu** `cn_leshan_giant_buddha` Leshan Giant Buddha — 127.9 km from the city centre
- **Chengdu** `cn_dujiangyan` Dujiangyan — 56.5 km from the city centre
- **Chiang Mai** `th_doi_inthanon` Doi Inthanon National Park — 57.1 km from the city centre
- **Reykjavik** `is_blue_lagoon_iceland` Blue Lagoon Iceland — 39.2 km from the city centre
- **Dakar** `sn_lac_rose` Lac Rose — 27.5 km from the city centre
- **Zanzibar** `tz_nungwi` Nungwi — 50.0 km from the city centre

## placeholder_coordinates (126)

- **Abu Dhabi** `auh_louvre_abudhabi` Louvre Abu Dhabi — (23.66667, 54.0) is a rounded number or the exact city centre, not the building's real location
- **Abu Dhabi** `auh_emirates_palace` Emirates Palace — (23.66667, 54.0) is a rounded number or the exact city centre, not the building's real location
- **Abu Dhabi** `auh_abrahamic_family_house` Abrahamic Family House — (23.66667, 54.0) is a rounded number or the exact city centre, not the building's real location
- **Abu Dhabi** `auh_guggenheim` Guggenheim Abu Dhabi (Upcoming) — (23.66667, 54.0) is a rounded number or the exact city centre, not the building's real location
- **Mumbai** `bom_rajabai` Rajabai Clock Tower — (19.0167, 72.85) is a rounded number or the exact city centre, not the building's real location
- **Mumbai** `bom_apple_bkc` Apple BKC — (19.07283, 72.88261) is a rounded number or the exact city centre, not the building's real location
- **Mumbai** `bom_national_gallery` NGMA (Sir Cowasji Jehangir Hall) — (19.0167, 72.85) is a rounded number or the exact city centre, not the building's real location
- **Tel Aviv** `tlv_museum_art` Tel Aviv Museum of Art — (32.08088, 34.78057) is a rounded number or the exact city centre, not the building's real location
- **Tel Aviv** `tlv_sourasky_library` Sourasky Central Library — (32.08088, 34.78057) is a rounded number or the exact city centre, not the building's real location
- **Barcelona** `bcn_pabellon` Barcelona Pavilion — (41.3888, 2.159) is a rounded number or the exact city centre, not the building's real location
- **Barcelona** `bcn_palau_musica` Palau de la Música Catalana — (41.3888, 2.159) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_shanghai_tower` Shanghai Tower — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_apple_campus` Apple Shanghai Campus — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_oriental_pearl` Oriental Pearl Tower — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_jin_mao` Jin Mao Tower — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_world_financial` Shanghai World Financial Center — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_china_art` China Art Museum — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Shanghai** `sha_shanghai_museum` Shanghai Museum (East) — (31.22222, 121.45806) is a rounded number or the exact city centre, not the building's real location
- **Bangkok** `bkk_maha_nakhon` King Power MahaNakhon — (13.7333, 100.5333) is a rounded number or the exact city centre, not the building's real location
- **Bangkok** `bkk_apple_central_world` Apple Central World — (13.7833, 100.5167) is a rounded number or the exact city centre, not the building's real location
- **Bangkok** `bkk_jim_thompson` Jim Thompson House — (13.7833, 100.5167) is a rounded number or the exact city centre, not the building's real location
- **Bangkok** `bkk_nailert_park` Nai Lert Park Heritage Home — (13.7833, 100.5167) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_tower` Cairo Tower — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_muhammad_ali` Mosque of Muhammad Ali — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_mogamma` The Mogamma — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_st_virgin_mary` The Hanging Church — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_opera_house` Cairo Opera House — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_apple_tradeline_cfc` Apple (Tradeline - Cairo Festival City) — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_abdeen_palace` Abdeen Palace — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_mosque_madrasa_sultan_hassan` Mosque-Madrasa of Sultan Hassan — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Cairo** `cai_egyptian_museum_tahrir` Museum of Egyptian Antiquities (The Red Museum) — (27.0, 30.0) is a rounded number or the exact city centre, not the building's real location
- **Mexico City** `mex_bellas_artes` Palacio de Bellas Artes — (23.0, -102.0) is a rounded number or the exact city centre, not the building's real location
- **Mexico City** `mex_postal_palace` Palacio de Correos de México — (23.0, -102.0) is a rounded number or the exact city centre, not the building's real location
- **Riyadh** `ruh-01` Kingdom Centre — (23.05, 45.55) is a rounded number or the exact city centre, not the building's real location
- **Riyadh** `ruh-03` Al Faisaliah Center — (23.05, 45.55) is a rounded number or the exact city centre, not the building's real location
- **Riyadh** `ruh-08` At-Turaif District (Diriyah) — (25.0, 45.0) is a rounded number or the exact city centre, not the building's real location
- **Riyadh** `ruh-apple-roshn` Apple ROSHN Front — (23.05, 45.55) is a rounded number or the exact city centre, not the building's real location
- **Cork** `crk-01` Saint Fin Barre's Cathedral — (51.89797, -8.47061) is a rounded number or the exact city centre, not the building's real location
- **Cork** `crk-apple-opera` Apple Opera Lane — (51.89797, -8.47061) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-tanah-lot` Pura Tanah Lot — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-tirta-gangga` Tirta Gangga Water Palace — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-green-school` The Green School (Heart of School) — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-gwk-statue` Garuda Wisnu Kencana (GWK Statue) — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-ulun-danu` Pura Ulun Danu Beratan — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-uluwatu` Pura Luhur Uluwatu — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-ubud-palace` Ubud Royal Palace (Puri Saren Agung) — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-potato-head` Potato Head Studios (Desa Potato Head) — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Bali** `bali-sharma-springs` Sharma Springs — (-8.5, 115.0) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-barelang-bridge` Barelang Bridge (Tengku Fisabilillah) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-great-mosque` Great Mosque of Batam (Masjid Raya) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-maitreya-monastery` Maha Vihara Duta Maitreya Monastery — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-tanjak-mosque` Masjid Tanwirun Naja (Tanjak Mosque) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-one-residence` One Residence Batam — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-galang-hospital` Galang Refugee Hospital (Historical Site) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-pollux-habibie` Meisterstadt (Pollux Habibie Towers) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-vihara-budhi-bhakti` Vihara Budhi Bhakti (Tua Pek Kong) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Batam** `batam-city-hall` Kantor Walikota Batam (City Hall) — (1.08333, 104.05) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-istiqlal` Istiqlal Mosque — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-autograph-tower` Autograph Tower (Thamrin Nine) — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-national-gallery` National Gallery of Indonesia — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-cathedral` Jakarta Cathedral — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-national-museum` National Museum (Gedung Gajah) — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-marathon-building` Indosat Building (Gedung Indosat) — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-perpusnas` National Library of Indonesia — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Central Jakarta** `jakarta-pos-bloc` Pos Bloc (Gedung Filateli) — (-6.21462, 106.84513) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-suramadu-bridge` Suramadu Bridge — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-hotel-majapahit` Hotel Majapahit — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-monkasel` Monkasel (Submarine Monument) — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-heroes-monument` Heroes Monument (Tugu Pahlawan) — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-al-akbar-mosque` Masjid Nasional Al-Akbar — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-house-of-sampoerna` House of Sampoerna — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-tunjungan-plaza` Tunjungan Plaza 6 — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-cheng-hoo-mosque` Cheng Hoo Mosque — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-de-javasche-bank` De Javasche Bank (Bank Indonesia Museum) — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-kyad-kyad` Kya-Kya Kembang Jepun — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-balai-pemuda` Balai Pemuda (Surabaya Culture Center) — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Surabaya** `sub-pakuwon-tower` Pakuwon Tower — (-7.24917, 112.75083) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-the-breeze` The Breeze BSD — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-ice-bsd` Indonesia Convention Exhibition (ICE) — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-scientia-square` Scientia Square Park (SQP) & SDC — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-uph-tower` Universitas Pelita Harapan (UPH) Tower — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-boen-tek-bio` Boen Tek Bio Chinese Temple — (-6.17806, 106.63) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-qbig-bsd` QBig BSD City — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-benteng-heritage` Benteng Heritage Museum — (-6.17806, 106.63) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-soekarno-hatta-t3` Soekarno-Hatta Terminal 3 — (-6.17806, 106.63) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-gop-office` Green Office Park 9 (GOP 9) — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-al-adzhom` Al-Adzhom Grand Mosque — (-6.17806, 106.63) is a rounded number or the exact city centre, not the building's real location
- **Tangerang** `tng-knowledge-hub` Traveloka Campus (Knowledge Hub) — (-6.25, 106.58333) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-sirius` Sirius (LNLS) — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-torre-do-castelo` Torre do Castelo — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-estacao-cultura` Estação Cultura — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-unicamp-library` Biblioteca Central Unicamp — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-jockey-club` Jockey Club Campineiro — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-teatro-castro-mendes` Teatro Castro Mendes — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-fazenda-santa-genebra` Mata de Santa Genebra Gatehouse — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Campinas** `cpq-galleria-shopping` Galleria Shopping Campinas — (-22.90556, -47.06083) is a rounded number or the exact city centre, not the building's real location
- **Curitiba** `cwb-memorial-ucraniano` Ukrainian Memorial — (-25.42778, -49.27306) is a rounded number or the exact city centre, not the building's real location
- **Curitiba** `cwb-apple-barigui` iPlace Apple Premium Partner (ParkShoppingBarigui) — (-25.42778, -49.27306) is a rounded number or the exact city centre, not the building's real location
- **Fortaleza** `for-cathedral` Metropolitan Cathedral of Fortaleza — (-3.71722, -38.54306) is a rounded number or the exact city centre, not the building's real location
- **Fortaleza** `for-apple-iguatemi` iPlace Apple Premium Partner (Iguatemi Bosque) — (-3.71722, -38.54306) is a rounded number or the exact city centre, not the building's real location
- **Manaus** `mao-amazon-theatre` Amazon Theatre (Teatro Amazonas) — (-3.10194, -60.025) is a rounded number or the exact city centre, not the building's real location
- **Manaus** `mao-fas` Amazonas Sustainable Foundation (FAS) — (-3.10194, -60.025) is a rounded number or the exact city centre, not the building's real location
- **Manaus** `mao-palacete-provincial` Palacete Provincial — (-3.10194, -60.025) is a rounded number or the exact city centre, not the building's real location
- **Manaus** `mao-rio-negro-bridge` Ponte Rio Negro — (-3.10194, -60.025) is a rounded number or the exact city centre, not the building's real location
- **Recife** `rec-malakoff-tower` Malakoff Tower — (-8.05389, -34.88111) is a rounded number or the exact city centre, not the building's real location
- **Recife** `rec-brennand-sculpture` Brennand Sculpture Park — (-8.05389, -34.88111) is a rounded number or the exact city centre, not the building's real location
- **Recife** `rec-officina-brennand` Officina Francisco Brennand — (-8.05389, -34.88111) is a rounded number or the exact city centre, not the building's real location
- **Pohang** `pohang-01` Space Walk — (36.08333, 129.36667) is a rounded number or the exact city centre, not the building's real location
- **Pohang** `pohang-05` Pohang Museum of Steel Art (POMA) — (36.08333, 129.36667) is a rounded number or the exact city centre, not the building's real location
- **Pohang** `pohang-10` Pohang Canal Pavilion — (36.08333, 129.36667) is a rounded number or the exact city centre, not the building's real location
- **Pohang** `pohang-apple-academy` Apple Developer Academy (POSTECH C5) — (36.08333, 129.36667) is a rounded number or the exact city centre, not the building's real location
- **Tokyo** `apple-japan-hq` Apple Japan Headquarters (Roppongi Hills Mori Tower) — (35.65, 139.73333) is a rounded number or the exact city centre, not the building's real location
- **Cape Town** `zeitz-mocaa` Zeitz MOCAA — (-33.9258, 18.4232) is a rounded number or the exact city centre, not the building's real location
- **Cape Town** `castle-of-good-hope` Castle of Good Hope — (-33.9258, 18.4232) is a rounded number or the exact city centre, not the building's real location
- **Prague** `st-vitus-cathedral` St. Vitus Cathedral — (50.08804, 14.42076) is a rounded number or the exact city centre, not the building's real location
- **Nairobi** `nairobi-national-museum` Nairobi National Museum — (-1.28333, 36.81667) is a rounded number or the exact city centre, not the building's real location
- **Marrakech** `dar-si-said` Dar Si Said Museum — (31.63416, -7.99994) is a rounded number or the exact city centre, not the building's real location
- **Lima** `basilica-cathedral-lima` Cathedral of Lima — (-12.04318, -77.02824) is a rounded number or the exact city centre, not the building's real location
- **Lima** `palacio-de-gobierno` Government Palace — (-12.04318, -77.02824) is a rounded number or the exact city centre, not the building's real location
- **Brasília** `br_cathedral_brasilia` Cathedral of Brasília — (-15.77972, -47.92972) is a rounded number or the exact city centre, not the building's real location
- **Brasília** `br_itamaraty_palace` Itamaraty Palace — (-15.77972, -47.92972) is a rounded number or the exact city centre, not the building's real location
- **Brasília** `br_national_museum` National Museum of the Republic — (28.41667, 79.38333) is a rounded number or the exact city centre, not the building's real location
- **Brasília** `br_pontao_lago_sul` Pontão do Lago Sul — (62.9833, 27.1) is a rounded number or the exact city centre, not the building's real location
- **Brasília** `br_national_library` National Library of Brasília — (28.41667, 79.38333) is a rounded number or the exact city centre, not the building's real location
- **St. Petersburg** `ru_peter_paul_fortress` Peter and Paul Fortress — (59.95, 30.3167) is a rounded number or the exact city centre, not the building's real location
- **Dakar** `sn_lac_rose` Lac Rose — (14.8333, -17.2333) is a rounded number or the exact city centre, not the building's real location

## city_centre_mismatch (1)

- **Cairo** — Landmarks' median is 362 km from the real city centre

## stacked_pins (62)

- **Bath** `uk_pulteney_bridge, uk_victoria_art_gallery` — 2 landmarks share (51.3828263, -2.358643)
- **Las Vegas** `lv_caesars, lv_encore` — 2 landmarks share (36.1480207, -115.1543981)
- **Dubai** `dxb_dubai_frame, dxb_jumeirah_emirates, dxb_etihad_museum` — 3 landmarks share (25.0657, 55.17128)
- **Bengaluru** `blr-01, blr-03` — 2 landmarks share (12.9914, 77.5944)
- **Hong Kong** `hk_ifc_two, hk_apple_ifc` — 2 landmarks share (22.2866255, 114.156663)
- **Beijing** `pek_forbidden_city, pek_galaxy_soho` — 2 landmarks share (39.93264, 116.41834)
- **Beijing** `pek_great_hall, pek_national_theatre` — 2 landmarks share (39.93317, 116.37337)
- **Beijing** `pek_citic_tower, pek_poly_victory` — 2 landmarks share (39.95462, 116.5029)
- **Abu Dhabi** `auh_louvre_abudhabi, auh_emirates_palace, auh_abrahamic_family_house, auh_guggenheim` — 4 landmarks share (23.66667, 54.0)
- **Abu Dhabi** `auh_yas_viceroy, auh_warner_bros` — 2 landmarks share (24.486404, 54.6090712)
- **Mumbai** `bom_cst, bom_municipal` — 2 landmarks share (18.6291, 72.8919)
- **Mumbai** `bom_gateway, bom_taj_palace` — 2 landmarks share (18.9219661, 72.8345657)
- **Mumbai** `bom_rajabai, bom_national_gallery` — 2 landmarks share (19.0167, 72.85)
- **Milan** `mil_duomo, mil_galleria` — 2 landmarks share (45.4639102, 9.1906398)
- **Copenhagen** `cph_black_diamond, cph_royal_library` — 2 landmarks share (55.6730401, 12.5810081)
- **Tel Aviv** `tlv_museum_art, tlv_sourasky_library` — 2 landmarks share (32.08088, 34.78057)
- **Tel Aviv** `tlv_azrieli, tlv_apple_sarona, tlv_sarona_tower` — 3 landmarks share (32.078307, 34.793389)
- **Barcelona** `bcn_pabellon, bcn_palau_musica` — 2 landmarks share (41.3888, 2.159)
- **Cupertino** `cup_le_petit_trianon, cup_fujitsu_planetarium, cup_vpac_de_anza` — 3 landmarks share (37.3209709, -122.0461135)
- **Shanghai** `sha_shanghai_tower, sha_apple_campus, sha_oriental_pearl, sha_jin_mao, sha_world_financial, sha_china_art, sha_shanghai_museum` — 7 landmarks share (31.22222, 121.45806)
- **Shanghai** `sha_customs_house, sha_shanghai_grand, sha_power_station, sha_peace_hotel` — 4 landmarks share (31.2378, 121.4781)
- **Bangkok** `bkk_grand_palace, bkk_wat_phra_kaew` — 2 landmarks share (13.7524072, 100.4903417)
- **Bangkok** `bkk_icon_siam, bkk_apple_iconsiam` — 2 landmarks share (13.7268226, 100.510294)
- **Bangkok** `bkk_apple_central_world, bkk_jim_thompson, bkk_nailert_park` — 3 landmarks share (13.7833, 100.5167)
- **Cairo** `cai_tower, cai_muhammad_ali, cai_mogamma, cai_st_virgin_mary, cai_opera_house, cai_apple_tradeline_cfc, cai_abdeen_palace, cai_mosque_madrasa_sultan_hassan, cai_egyptian_museum_tahrir` — 9 landmarks share (27.0, 30.0)
- **Mexico City** `mex_bellas_artes, mex_postal_palace` — 2 landmarks share (23.0, -102.0)
- **Mexico City** `mex_soumaya, mex_jumex` — 2 landmarks share (19.4410129, -99.1968752)
- **Mexico City** `mex_met_cathedral, mex_torre_latino` — 2 landmarks share (19.44506, -99.14612)
- **Riyadh** `ruh-01, ruh-03, ruh-apple-roshn` — 3 landmarks share (23.05, 45.55)
- **Riyadh** `ruh-06, ruh-09, ruh-11` — 3 landmarks share (24.7656964, 46.6407087)
- **Riyadh** `ruh-07, ruh-13` — 2 landmarks share (24.8460149, 46.7317529)
- **Cork** `crk-01, crk-apple-opera` — 2 landmarks share (51.89797, -8.47061)
- **St. Louis** `stl-01, stl-11` — 2 landmarks share (38.6246257, -90.1849637)
- **Naples** `nap-04, nap-08` — 2 landmarks share (40.8387165, 14.2513842)
- **Bali** `bali-tanah-lot, bali-tirta-gangga, bali-green-school, bali-gwk-statue, bali-ulun-danu, bali-uluwatu, bali-ubud-palace, bali-potato-head, bali-sharma-springs` — 9 landmarks share (-8.5, 115.0)
- **Batam** `batam-barelang-bridge, batam-great-mosque, batam-maitreya-monastery, batam-tanjak-mosque, batam-one-residence, batam-galang-hospital, batam-pollux-habibie, batam-vihara-budhi-bhakti, batam-city-hall` — 9 landmarks share (1.08333, 104.05)
- **Batam** `batam-nagoya-hill, batam-apple-grand` — 2 landmarks share (1.13924, 104.01237)
- **Central Jakarta** `jakarta-istiqlal, jakarta-autograph-tower, jakarta-national-gallery, jakarta-cathedral, jakarta-national-museum, jakarta-marathon-building, jakarta-perpusnas, jakarta-pos-bloc` — 8 landmarks share (-6.21462, 106.84513)
- **Surabaya** `sub-suramadu-bridge, sub-hotel-majapahit, sub-monkasel, sub-heroes-monument, sub-al-akbar-mosque, sub-house-of-sampoerna, sub-tunjungan-plaza, sub-cheng-hoo-mosque, sub-de-javasche-bank, sub-kyad-kyad, sub-balai-pemuda, sub-pakuwon-tower` — 12 landmarks share (-7.24917, 112.75083)
- **Tangerang** `tng-the-breeze, tng-ice-bsd, tng-scientia-square, tng-uph-tower, tng-qbig-bsd, tng-gop-office, tng-knowledge-hub` — 7 landmarks share (-6.25, 106.58333)
- **Tangerang** `tng-boen-tek-bio, tng-benteng-heritage, tng-soekarno-hatta-t3, tng-al-adzhom` — 4 landmarks share (-6.17806, 106.63)
- **Campinas** `cpq-sirius, cpq-torre-do-castelo, cpq-estacao-cultura, cpq-unicamp-library, cpq-jockey-club, cpq-teatro-castro-mendes, cpq-fazenda-santa-genebra, cpq-galleria-shopping` — 8 landmarks share (-22.90556, -47.06083)
- **Curitiba** `cwb-memorial-ucraniano, cwb-apple-barigui` — 2 landmarks share (-25.42778, -49.27306)
- **Curitiba** `cwb-tube-station, cwb-cathedral-basilica` — 2 landmarks share (-25.4297354, -49.2719544)
- **Fortaleza** `for-cathedral, for-apple-iguatemi` — 2 landmarks share (-3.71722, -38.54306)
- **Manaus** `mao-amazon-theatre, mao-fas, mao-palacete-provincial, mao-rio-negro-bridge` — 4 landmarks share (-3.10194, -60.025)
- **Manaus** `mao-custom-house, mao-floating-harbor` — 2 landmarks share (-3.137786, -60.0247438)
- **Porto Alegre** `poa-piratini, poa-apple-iguatemi` — 2 landmarks share (-30.03306, -51.23)
- **Recife** `rec-malakoff-tower, rec-brennand-sculpture, rec-officina-brennand` — 3 landmarks share (-8.05389, -34.88111)
- **Pohang** `pohang-01, pohang-05, pohang-10, pohang-apple-academy` — 4 landmarks share (36.08333, 129.36667)
- **Pohang** `pohang-03, pohang-09` — 2 landmarks share (35.9863018, 129.4803929)
- **Tokyo** `glbl_apple_marunouchi, tokyo-station` — 2 landmarks share (35.6802, 139.7642)
- **Tokyo** `nakagin-capsule, glbl_apple_ginza` — 2 landmarks share (35.6706, 139.7649)
- **Cape Town** `zeitz-mocaa, castle-of-good-hope` — 2 landmarks share (-33.9258, 18.4232)
- **Lisbon** `maat-lisbon, belem-tower` — 2 landmarks share (38.6962598, -9.1954109)
- **Nairobi** `kicc-nairobi, cbk-pension-tower` — 2 landmarks share (-1.2884884, 36.8253662)
- **Marrakech** `bahia-palace, el-badi-palace` — 2 landmarks share (31.6205, -7.98466)
- **Lima** `basilica-cathedral-lima, palacio-de-gobierno` — 2 landmarks share (-12.04318, -77.02824)
- **Brasília** `br_cathedral_brasilia, br_itamaraty_palace` — 2 landmarks share (-15.77972, -47.92972)
- **Brasília** `br_national_congress, br_planalto_palace, br_supreme_court, br_pantheon_liberty` — 4 landmarks share (-15.8011592, -47.8613363)
- **Brasília** `br_national_museum, br_national_library` — 2 landmarks share (28.41667, 79.38333)
- **São Paulo** `br_altino_arantes, br_theatre_municipal` — 2 landmarks share (-23.38193, -48.72265)

## implausible_year (5)

- **Taipei** `taipei-elephant-mountain` Xiangshan (Taipei) — yearBuilt is 0 (probably unknown)
- **Addis Ababa** `addis-entoto-mountain` Mount Entoto — yearBuilt is 0 (probably unknown)
- **Guadalajara** `mx_barranca_huentitan` Barranca de Huentítán — yearBuilt is 0 (probably unknown)
- **Dakar** `sn_lac_rose` Lac Rose — yearBuilt is 0 (probably unknown)
- **Zanzibar** `tz_nungwi` Nungwi — yearBuilt is 0 (probably unknown)

## empty_text (1)

- **Victoria** `vic-10` Mayfair Shopping Centre — architect is 'N/A'

## suspicious_size (11)

- **Berlin** `ber_tv_tower` Berliner Fernsehturm — 368 m for 4 stories is 92 m/storey
- **Barcelona** `bcn_torre_communications` Montjuïc Communications Tower — 136 m for 3 stories is 45 m/storey
- **Central Jakarta** `jakarta-monas` National Monument (Monas) — 132 m for 3 stories is 44 m/storey
- **Paris** `paris-eiffel-tower` Eiffel Tower — 330 m for 3 stories is 110 m/storey
- **Seoul** `n-seoul-tower` N Seoul Tower — 236 m for 5 stories is 47 m/storey
- **Brasília** `br_tv_tower` Brasília TV Tower — 224 m for 4 stories is 56 m/storey
- **Bogotá** `bogota-monserrate` Monserrate — taller than the world's tallest building (stories=1, height=3152.0)
- **Casablanca** `casablanca-hassan-ii` Hassan II Mosque — 210.0 m for 4 stories is 52 m/storey
- **Lagos** `lagos-nike-art-gallery` Nike Art Gallery — 6 m for 5 stories is only 1.2 m/storey (feet?)
- **Addis Ababa** `addis-entoto-mountain` Mount Entoto — taller than the world's tallest building (stories=1, height=3200.0)
- **Amman** `amman-citadel` Amman Citadel — taller than the world's tallest building (stories=1, height=850.0)

## height_unknown (65)

- **Athens** `athens-agora` Ancient Agora of Athens — 1 stories but height is 0
- **Edinburgh** `edinburgh-royal-mile` Royal Mile — 1 stories but height is 0
- **Venice** `venice-grand-canal` Grand Canal (Venice) — 1 stories but height is 0
- **Madrid** `madrid-retiro-park` Buen Retiro Park — 1 stories but height is 0
- **Madrid** `madrid-plaza-mayor` Plaza Mayor, Madrid — 4 stories but height is 0
- **Osaka** `osaka-dotonbori` Dotonbori — 1 stories but height is 0
- **Osaka** `osaka-shinsekai` Shinsekai — 1 stories but height is 0
- **Johannesburg** `johannesburg-walter-sisulu-garden` Walter Sisulu National Botanical Garden — 1 stories but height is 0
- **Johannesburg** `johannesburg-vilakazi-street` Vilakazi Street — 1 stories but height is 0
- **Ho Chi Minh City** `hcmc-ben-thanh-market` Bến Thành Market — 1 stories but height is 0
- **Ho Chi Minh City** `hcmc-cu-chi-tunnels` Cu Chi tunnels — 1 stories but height is 0
- **Zurich** `zurich-bahnhofstrasse` Bahnhofstrasse — 1 stories but height is 0
- **Stockholm** `stockholm-gamla-stan` Gamla stan — 4 stories but height is 0
- **Stockholm** `stockholm-skansen` Skansen — 1 stories but height is 0
- **Bogotá** `bogota-la-candelaria` La Candelaria — 2 stories but height is 0
- **Casablanca** `casablanca-mohammed-v-square` Mohammed V Square (Casablanca) — 1 stories but height is 0
- **Casablanca** `casablanca-old-medina` Old Medina of Casablanca — 2 stories but height is 0
- **Casablanca** `casablanca-corniche` Ain Diab — 2 stories but height is 0
- **Lagos** `lagos-tafawa-balewa-square` Tafawa Balewa Square — 1 stories but height is 0
- **Lagos** `lagos-freedom-park` Freedom Park (Lagos) — 2 stories but height is 0
- **Accra** `accra-kwame-nkrumah-mausoleum` Kwame Nkrumah Mausoleum and Memorial Park — 1 stories but height is 0
- **Accra** `accra-makola-market` Makola Market — 1 stories but height is 0
- **Doha** `doha-the-pearl` The Pearl, Qatar — 10 stories but height is 0
- **Amman** `amman-rainbow-street` Rainbow Street, Amman — 2 stories but height is 0
- **Manila** `manila-intramuros` Intramuros — 2 stories but height is 0
- **Manila** `manila-rizal-park` Rizal Park — 1 stories but height is 0
- **Oslo** `oslo-vigeland-park` Vigeland installation — 1 stories but height is 0
- **Helsinki** `helsinki-suomenlinna` Suomenlinna — 2 stories but height is 0
- **Helsinki** `helsinki-market-square` Market Square, Helsinki — 1 stories but height is 0
- **Warsaw** `warsaw-old-town` Warsaw Old Town — 4 stories but height is 0
- **Havana** `havana-old-havana` Old Havana — 3 stories but height is 0
- **Havana** `havana-malecon` Malecón (Havana) — 1 stories but height is 0
- **Sana'a** `sanaa-old-city` Old Sana'a — 6 stories but height is 0
- **Xi'an** `cn_terracotta_army` Terracotta Army — 1 stories but height is 0
- **Xi'an** `cn_muslim_quarter_xian` Muslim Quarter, Xi'an — 1 stories but height is 0
- **Chengdu** `cn_chengdu_panda_base` Chengdu Research Base of Giant Panda Breeding — 1 stories but height is 0
- **Chengdu** `cn_jinli_ancient_street` Jinli Ancient Street — 2 stories but height is 0
- **Chengdu** `cn_dujiangyan` Dujiangyan — 1 stories but height is 0
- **Medellín** `co_pueblito_paisa` Pueblito Paisa — 1 stories but height is 0
- **Medellín** `co_metrocable_medellin` Metrocable Medellín — 1 stories but height is 0
- **Medellín** `co_plaza_botero` Plaza Botero — 1 stories but height is 0
- **Medellín** `co_jardin_botanico_medellin` Jardín Botánico de Medellín — 1 stories but height is 0
- **Fukuoka** `jp_canal_city_hakata` Canal City Hakata — 9 stories but height is 0
- **Fukuoka** `jp_ohori_park` Ohori Park — 1 stories but height is 0
- **Chiang Mai** `th_chiang_mai_night_bazaar` Chiang Mai Night Bazaar — 2 stories but height is 0
- **Chiang Mai** `th_doi_inthanon` Doi Inthanon National Park — 1 stories but height is 0
- **Nice** `fr_promenade_des_anglais` Promenade des Anglais — 1 stories but height is 0
- **Nice** `fr_castle_hill_nice` Castle Hill, Nice — 1 stories but height is 0
- **Guadalajara** `mx_tlaquepaque` Tlaquepaque — 2 stories but height is 0
- **Guadalajara** `mx_barranca_huentitan` Barranca de Huentítán — 1 stories but height is 0
- **Quebec City** `ca_citadelle_quebec` Citadelle of Quebec — 2 stories but height is 0
- **Quebec City** `ca_plains_of_abraham` Plains of Abraham — 1 stories but height is 0
- **Quebec City** `ca_funiculaire_quebec` Funiculaire du Vieux-Québec — 1 stories but height is 0
- **Quebec City** `ca_petit_champlain` Quartier Petit-Champlain — 2 stories but height is 0
- **Brisbane** `au_south_bank_parklands` South Bank Parklands — 1 stories but height is 0
- **Brisbane** `au_mt_coottha_lookout` Mount Coot-tha Lookout — 1 stories but height is 0
- **Kathmandu** `np_kathmandu_durbar_square` Kathmandu Durbar Square — 3 stories but height is 0
- **Kathmandu** `np_garden_of_dreams` Garden of Dreams, Kathmandu — 1 stories but height is 0
- **Reykjavik** `is_blue_lagoon_iceland` Blue Lagoon Iceland — 1 stories but height is 0
- **Tbilisi** `ge_tbilisi_botanical_garden` Tbilisi Botanical Garden — 1 stories but height is 0
- **Colombo** `lk_pettah_market` Pettah Market — 2 stories but height is 0
- **Colombo** `lk_galle_face_green` Galle Face Green — 1 stories but height is 0
- **Dakar** `sn_lac_rose` Lac Rose — 1 stories but height is 0
- **Zanzibar** `tz_stone_town` Stone Town, Zanzibar City — 3 stories but height is 0
- **Zanzibar** `tz_nungwi` Nungwi — 1 stories but height is 0

## too_few_landmarks (1)

- **Queenstown** — only 1 mappable landmarks (quiz needs 4)
