# Editable registry for quick edits in VS Code.
# Edit REGISTRY here in VS Code and run:
#   ./scripts/convert_registry.py import
# to write changes into Stamped! A City Passport/Resources/BuildingRegistry.json

import json
from pathlib import Path

# Path to the canonical JSON (relative to repo root).
DEFAULT_JSON_PATH = Path(__file__).resolve().parents[1] / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"

# Try to load the full JSON if it exists (read file directly; avoid package imports).
LOADED_REGISTRY = {}
try:
    if DEFAULT_JSON_PATH.exists():
        with DEFAULT_JSON_PATH.open("r", encoding="utf-8") as f:
            LOADED_REGISTRY = json.load(f)
except Exception:
    LOADED_REGISTRY = {}

# Start with either the loaded registry or a small fallback example.
if LOADED_REGISTRY:
    REGISTRY = LOADED_REGISTRY
else:
    REGISTRY = {
        "Bath": [
            {
                "id": "uk_roman_baths",
                "name": "The Roman Baths",
                "assetName": "romanBaths",
                "description": "Constructed around 70 AD...",
                "architect": "Ancient Romans",
                "yearBuilt": 70,
                "address": "Abbey Churchyard, Bath BA1 1LZ",
                "oldUse": "Public Bathing House",
                "newUse": "Museum / Historical Site",
                "buildingStyle": "Roman / Neoclassical",
                "numberOfStories": 2,
                "height": 12,
                "foodSpots": ["The Pump Room"],
                "currency": "GBP (£)"
            }
        ]
    }


    
# Merge in any loaded registry entries not present (safe union).
for city, buildings in LOADED_REGISTRY.items():
    if city not in REGISTRY:
        REGISTRY[city] = buildings
    else:
        # Append new buildings if duplicates should be included; adjust if needed
        REGISTRY[city] += buildings

# Add Brasília if missing
if "Brasília" not in REGISTRY:
    REGISTRY["Brasília"] = [
        {
            "id": "br_cathedral_brasilia",
            "name": "Cathedral of Brasília",
            "assetName": "cathedralBrasilia",
            "description": "A modernist masterpiece featuring 16 curved concrete columns weighing 90 tons each. The design represents hands reaching toward heaven, with a nave bathed in light from vast stained-glass panels. Visitors enter through a dark underground tunnel to experience a dramatic transition into the bright, airy interior.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1970,
            "address": "Esplanada dos Ministérios, Brasília - DF, 70050-000",
            "oldUse": "Religious Site",
            "newUse": "Religious Site / Landmark",
            "buildingStyle": "Modernist",
            "numberOfStories": 1,
            "height": 40,
            "foodSpots": ["Mangai", "L’Alcofa"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_national_congress",
            "name": "National Congress of Brazil",
            "assetName": "nationalCongress",
            "description": "The center of Brazilian legislative power, consisting of twin 28-story towers flanked by a convex dome (Chamber of Deputies) and a concave dome (Federal Senate). It is arguably the most famous silhouette in the city, symbolizing the balance of the nation's political structure.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1960,
            "address": "Praça dos Três Poderes, Brasília - DF, 70160-900",
            "oldUse": "Legislative Seat",
            "newUse": "Legislative Seat",
            "buildingStyle": "Modernist",
            "numberOfStories": 28,
            "height": 92,
            "foodSpots": ["Senado Federal Restaurant", "Villa Tevere"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_itamaraty_palace",
            "name": "Itamaraty Palace",
            "assetName": "itamaratyPalace",
            "description": "Also known as the 'Palace of the Arches,' this is the headquarters of the Ministry of Foreign Affairs. It features a facade of concrete arches over a reflecting pool. The interior is a marvel of engineering, boasting a grand spiral staircase and large open halls without any supporting columns.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1970,
            "address": "Esplanada dos Ministérios, Bloco H, Brasília - DF, 70170-900",
            "oldUse": "Government Office",
            "newUse": "Government Office / Museum",
            "buildingStyle": "Modernist",
            "numberOfStories": 3,
            "height": 15,
            "foodSpots": ["Dom Francisco", "Coco Bambu"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_jk_bridge",
            "name": "Juscelino Kubitschek Bridge",
            "assetName": "jkBridge",
            "description": "A striking steel bridge with three asymmetrical arches that 'hop' across Lake Paranoá. The design mimics the movement of a stone skipping across water. It has become a symbol of the city’s modernity and is a popular spot for viewing the sunset over the lake.",
            "architect": "Alexandre Chan",
            "yearBuilt": 2002,
            "address": "Setor de Clubes Esportivos Sul, Brasília - DF",
            "oldUse": "Infrastructure",
            "newUse": "Infrastructure / Landmark",
            "buildingStyle": "Contemporary / Expressionist",
            "numberOfStories": 1,
            "height": 60,
            "foodSpots": ["BierFass Lago", "Mizu"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_alvorada_palace",
            "name": "Palácio da Alvorada",
            "assetName": "alvoradaPalace",
            "description": "The official residence of the President of Brazil. Its name translates to 'Palace of the Dawn.' The building is famous for its iconic white marble columns, which have become a logo for the city of Brasília itself. It sits on a peninsula jutting into Lake Paranoá.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1958,
            "address": "Via Presidencial, Brasília - DF, 70150-903",
            "oldUse": "Presidential Residence",
            "newUse": "Presidential Residence",
            "buildingStyle": "Modernist",
            "numberOfStories": 3,
            "height": 18,
            "foodSpots": ["Old Barracuda", "The Falls"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_tv_tower",
            "name": "Brasília TV Tower",
            "assetName": "tvTower",
            "description": "One of the few major landmarks not designed by Niemeyer, this iron tower offers the best panoramic view of the 'airplane' layout of the city. An observation deck at 75 meters provides a clear view of the Monumental Axis. It is a hub for local craft markets and street food.",
            "architect": "Lúcio Costa",
            "yearBuilt": 1967,
            "address": "Eixo Monumental, Brasília - DF, 70070-300",
            "oldUse": "Telecommunications",
            "newUse": "Telecommunications / Observation",
            "buildingStyle": "Modernist / Industrial",
            "numberOfStories": 4,
            "height": 224,
            "foodSpots": ["Bar 16 (B Hotel)", "Feira da Torre"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_national_museum",
            "name": "National Museum of the Republic",
            "assetName": "nationalMuseum",
            "description": "A semi-spherical white dome that looks like a planet emerging from the ground. It features an external ramp that winds around the building to the entrance. The museum hosts traveling art exhibitions and is part of the Cultural Complex of the Republic.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 2006,
            "address": "Setor Cultural Sul, Lote 2, Brasília - DF, 70070-150",
            "oldUse": "Museum",
            "newUse": "Museum",
            "buildingStyle": "Modernist / Futurist",
            "numberOfStories": 2,
            "height": 26,
            "foodSpots": ["Calaf", "Deboche! Bar"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_jk_memorial",
            "name": "Memorial JK",
            "assetName": "jkMemorial",
            "description": "A museum and mausoleum dedicated to Juscelino Kubitschek, the president who founded Brasília. It contains his tomb, personal library, and artifacts from the city's construction. The exterior features a prominent curved pedestal supporting a statue of the president.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1981,
            "address": "Eixo Monumental, Praça do Cruzeiro, Brasília - DF",
            "oldUse": "Memorial",
            "newUse": "Museum / Memorial",
            "buildingStyle": "Modernist",
            "numberOfStories": 2,
            "height": 28,
            "foodSpots": ["Restaurante Universal", "Taypá"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_sanctuary_dom_bosco",
            "name": "Sanctuary of Don Bosco",
            "assetName": "domBoscoSanctuary",
            "description": "Famous for its 80 towering columns and walls made almost entirely of blue Murano glass. The light filtering through the glass creates an immersive 'underwater' blue atmosphere inside. It honors the Italian saint who supposedly had a prophetic vision of Brasília in 1883.",
            "architect": "Carlos Alberto Naves",
            "yearBuilt": 1970,
            "address": "SEPS 702, Lote B, Brasília - DF, 70330-710",
            "oldUse": "Religious Site",
            "newUse": "Religious Site",
            "buildingStyle": "Modernist / Gothic Influence",
            "numberOfStories": 1,
            "height": 30,
            "foodSpots": ["Bloco C", "Ticiana Werner"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_national_theater",
            "name": "Cláudio Santoro National Theater",
            "assetName": "nationalTheater",
            "description": "Designed in the shape of a truncated pyramid, this is the largest building designed by Niemeyer specifically for the arts. Its lateral facades are covered in an abstract concrete relief. It houses three main halls named after famous musicians and composers.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1966,
            "address": "Setor Cultural Norte, Via N2, Brasília - DF, 70070-200",
            "oldUse": "Theater",
            "newUse": "Theater",
            "buildingStyle": "Modernist",
            "numberOfStories": 4,
            "height": 25,
            "foodSpots": ["Cantucci Bistro", "Norton Grill"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_pontao_lago_sul",
            "name": "Pontão do Lago Sul",
            "assetName": "pontaoLagoSul",
            "description": "A premier lakeside leisure complex that serves as a modern gathering point for locals. While not a single building, its design integrates multiple structures into a scenic waterfront park featuring walkways, palm trees, and piers overlooking Lake Paranoá.",
            "architect": "Various",
            "yearBuilt": 2001,
            "address": "SHIS QL 10, Lote 1/30, Brasília - DF, 71630-115",
            "oldUse": "Lakeside Area",
            "newUse": "Dining / Leisure Hub",
            "buildingStyle": "Contemporary",
            "numberOfStories": 1,
            "height": 8,
            "foodSpots": ["Sallva Bar", "Manzuá", "Izzi Wine Garden"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_planalto_palace",
            "name": "Palácio do Planalto",
            "assetName": "planaltoPalace",
            "description": "The official workplace of the President. Like the Alvorada, it features elegant, thin columns that suggest a 'floating' structure. It is located on the Praça dos Três Poderes and is where the presidential sash is handed over during inaugurations.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1960,
            "address": "Praça dos Três Poderes, Brasília - DF, 70150-900",
            "oldUse": "Executive Office",
            "newUse": "Executive Office",
            "buildingStyle": "Modernist",
            "numberOfStories": 4,
            "height": 20,
            "foodSpots": ["Dudu Bar", "Jamie Oliver Kitchen"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_supreme_court",
            "name": "Supreme Federal Court",
            "assetName": "supremeCourt",
            "description": "The third pillar of the Three Powers Plaza, this building is known for its classic Niemeyer arches and 'The Blind Justice' sculpture by Alfredo Ceschiatti sitting in front. It maintains the architectural language of the Planalto Palace to signify equality between branches of government.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1960,
            "address": "Praça dos Três Poderes, Brasília - DF, 70175-900",
            "oldUse": "Judicial Seat",
            "newUse": "Judicial Seat",
            "buildingStyle": "Modernist",
            "numberOfStories": 3,
            "height": 16,
            "foodSpots": ["Fogo de Chão", "Coco Bambu"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_national_library",
            "name": "National Library of Brasília",
            "assetName": "nationalLibrary",
            "description": "A sleek, rectangular concrete and glass structure that sits adjacent to the National Museum. It represents the 'modernity of knowledge' and features expansive reading rooms with views of the Monumental Axis. It is a key part of the city's cultural sector.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 2008,
            "address": "Setor Cultural Sul, Lote 2, Brasília - DF, 70070-150",
            "oldUse": "Library",
            "newUse": "Library",
            "buildingStyle": "Modernist",
            "numberOfStories": 4,
            "height": 22,
            "foodSpots": ["Calaf", "Vasto Restaurante"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_pantheon_liberty",
            "name": "Pantheon of Liberty and Democracy",
            "assetName": "pantheonLiberty",
            "description": "Built in the shape of a dove, this monument honors those who fought for democracy in Brazil. Inside, the 'Book of National Heroes' records the names of figures who impacted the nation's history. It was built following the restoration of civilian rule in the 1980s.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1986,
            "address": "Praça dos Três Poderes, Brasília - DF",
            "oldUse": "Monument",
            "newUse": "Monument / Museum",
            "buildingStyle": "Modernist",
            "numberOfStories": 2,
            "height": 12,
            "foodSpots": ["Senado Restaurant", "Villa Tevere"],
            "currency": "BRL (R$)"
        }
    ]

if "São Paulo" not in REGISTRY:
    REGISTRY["São Paulo"] = [
        {
            "id": "br_masp",
            "name": "MASP (São Paulo Museum of Art)",
            "assetName": "masp",
            "description": "A landmark of Brazilian Brutalism, this building is famous for its 'floating' main body, suspended by two massive red concrete arches. The 74-meter clear span underneath creates a vast public plaza (vão livre) that hosts markets and protests on Paulista Avenue.",
            "architect": "Lina Bo Bardi",
            "yearBuilt": 1968,
            "address": "Av. Paulista, 1578, Bela Vista, São Paulo - SP",
            "oldUse": "Museum",
            "newUse": "Museum / Cultural Center",
            "buildingStyle": "Brutalist",
            "numberOfStories": 2,
            "height": 15,
            "foodSpots": ["A Baianeira MASP", "Mirante 9 de Julho"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_copan",
            "name": "Edifício Copan",
            "assetName": "copanBuilding",
            "description": "One of the largest residential buildings in the world, known for its iconic S-shaped wave facade and brise-soleil concrete slats. It contains over 1,100 apartments and a ground-floor commercial arcade, embodying a 'city within a building' concept.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 1966,
            "address": "Av. Ipiranga, 200, Centro Histórico, São Paulo - SP",
            "oldUse": "Residential / Commercial",
            "newUse": "Residential / Commercial",
            "buildingStyle": "Modernist",
            "numberOfStories": 38,
            "height": 115,
            "foodSpots": ["Bar da Dona Onça", "Cuia Café"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_altino_arantes",
            "name": "Farol Santander (Altino Arantes Building)",
            "assetName": "farolSantander",
            "description": "Often called the 'Empire State Building of Brazil,' this Art Deco skyscraper was the tallest reinforced concrete building in the world when finished. Its observation deck offers a 360-degree view of the city's 'sea of skyscrapers.'",
            "architect": "Plínio Botelho do Amaral",
            "yearBuilt": 1947,
            "address": "Rua João Brícola, 24, Centro, São Paulo - SP",
            "oldUse": "Bank Headquarters",
            "newUse": "Cultural Center / Observation Deck",
            "buildingStyle": "Art Deco",
            "numberOfStories": 35,
            "height": 161,
            "foodSpots": ["Mag Café", "Boteco do 28"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_estaiada_bridge",
            "name": "Octávio Frias de Oliveira Bridge",
            "assetName": "estaiadaBridge",
            "description": "Commonly known as Ponte Estaiada, this is the only bridge in the world with two curved tracks supported by a single X-shaped concrete mast. It is the most modern architectural icon of the city's southern financial district.",
            "architect": "Catão Francisco Ribeiro",
            "yearBuilt": 2008,
            "address": "Marginal Pinheiros, Brooklin, São Paulo - SP",
            "oldUse": "Bridge",
            "newUse": "Bridge / Landmark",
            "buildingStyle": "Cable-stayed / High-tech",
            "numberOfStories": 1,
            "height": 138,
            "foodSpots": ["NB Steak", "Fogo de Chão"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_theatre_municipal",
            "name": "Theatro Municipal de São Paulo",
            "assetName": "municipalTheatre",
            "description": "Inspired by the Palais Garnier in Paris, this lavish building features an eclectic mix of Renaissance, Baroque, and Art Nouveau styles. It was the stage for the 1922 Modern Art Week, which revolutionized Brazilian culture.",
            "architect": "Ramos de Azevedo",
            "yearBuilt": 1911,
            "address": "Praça Ramos de Azevedo, Centro, São Paulo - SP",
            "oldUse": "Opera House",
            "newUse": "Opera House / Concert Hall",
            "buildingStyle": "Eclectic / Neo-Classical",
            "numberOfStories": 4,
            "height": 28,
            "foodSpots": ["Bar dos Arcos", "Sertó"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_pinacoteca",
            "name": "Pinacoteca do Estado",
            "assetName": "pinacoteca",
            "description": "The oldest art museum in São Paulo. A 1990s renovation by Pritzker-winner Paulo Mendes da Rocha left the internal exposed brickwork and added steel walkways and glass roofs, creating a stunning dialogue between old and new.",
            "architect": "Ramos de Azevedo / Paulo Mendes da Rocha (Renovation)",
            "yearBuilt": 1900,
            "address": "Praça da Luz, 2, Luz, São Paulo - SP",
            "oldUse": "Arts & Crafts School",
            "newUse": "Art Museum",
            "buildingStyle": "Neo-Renaissance / Industrial",
            "numberOfStories": 3,
            "height": 20,
            "foodSpots": ["Café da Pina", "Acropoli"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_estacao_da_luz",
            "name": "Luz Station",
            "assetName": "luzStation",
            "description": "A grand railway station prefabricated in Glasgow and shipped to Brazil. It features a clock tower inspired by Big Ben and a massive iron canopy over the tracks, reflecting the British influence on Brazil's early coffee-wealth infrastructure.",
            "architect": "Charles Henry Driver",
            "yearBuilt": 1901,
            "address": "Praça da Luz, 1, Luz, São Paulo - SP",
            "oldUse": "Railway Station",
            "newUse": "Railway Station / Museum of Portuguese Language",
            "buildingStyle": "Victorian / Neoclassical",
            "numberOfStories": 3,
            "height": 35,
            "foodSpots": ["Florina", "Tradi"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_cathedral_se",
            "name": "São Paulo Cathedral (Catedral da Sé)",
            "assetName": "seCathedral",
            "description": "One of the five largest Neo-Gothic cathedrals in the world. It features a massive dome inspired by the Florence Cathedral and thousands of tons of marble. The crypt beneath the altar is a sprawling underground cathedral in its own right.",
            "architect": "Maximilian Emil Hehl",
            "yearBuilt": 1954,
            "address": "Praça da Sé, Centro, São Paulo - SP",
            "oldUse": "Religious Site",
            "newUse": "Religious Site",
            "buildingStyle": "Neo-Gothic",
            "numberOfStories": 1,
            "height": 92,
            "foodSpots": ["Ponto Chic", "Casa Mathilde"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_sesc_pompeia",
            "name": "SESC Pompéia",
            "assetName": "sescPompeia",
            "description": "A former drum factory converted into a culture and leisure center. The architect used raw concrete and exposed water pipes, linking two massive concrete towers with dramatic 'aerial' walkways. It is considered a masterpiece of adaptive reuse.",
            "architect": "Lina Bo Bardi",
            "yearBuilt": 1982,
            "address": "Rua Clélia, 93, Água Branca, São Paulo - SP",
            "oldUse": "Factory",
            "newUse": "Cultural / Sports Center",
            "buildingStyle": "Brutalist",
            "numberOfStories": 10,
            "height": 45,
            "foodSpots": ["SESC Cafeteria", "Pizzaria Speranza"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_italia_building",
            "name": "Edifício Itália",
            "assetName": "italiaBuilding",
            "description": "With its slender, curved facade and 46 stories, this was long the city's second-tallest building. It is famous for the 'Terraço Itália' restaurant at the top, which offers the most upscale panoramic dining experience in São Paulo.",
            "architect": "Franz Heep",
            "yearBuilt": 1965,
            "address": "Av. Ipiranga, 344, República, São Paulo - SP",
            "oldUse": "Commercial / Club",
            "newUse": "Commercial / Dining",
            "buildingStyle": "International Style",
            "numberOfStories": 46,
            "height": 165,
            "foodSpots": ["Terraço Itália", "A Casa do Porco"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_mosteiro_sao_bento",
            "name": "Saint Benedict Monastery",
            "assetName": "saoBentoMonastery",
            "description": "A historic monastery with a sober exterior but a rich, gold-filled interior featuring German Beuron art. It is famous for its daily Gregorian chants and its high-end bakery run by the monks, selling traditional breads and cakes.",
            "architect": "Richard Berndl",
            "yearBuilt": 1922,
            "address": "Largo de São Bento, Centro, São Paulo - SP",
            "oldUse": "Monastery / Church",
            "newUse": "Monastery / Church / Bakery",
            "buildingStyle": "Eclectic / Romanesque Revival",
            "numberOfStories": 2,
            "height": 25,
            "foodSpots": ["Padaria do Mosteiro", "Salve Jorge"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_mercadao",
            "name": "Municipal Market of São Paulo",
            "assetName": "mercadao",
            "description": "Commonly known as 'Mercadão,' this building is famous for its massive stained-glass windows depicting agricultural life. It is the gastronomic heart of the city, renowned for its giant mortadella sandwiches and exotic fruit stalls.",
            "architect": "Ramos de Azevedo",
            "yearBuilt": 1933,
            "address": "Rua Cantareira, 306, Centro, São Paulo - SP",
            "oldUse": "Market",
            "newUse": "Gastronomic Market",
            "buildingStyle": "Eclectic / Art Deco Influence",
            "numberOfStories": 2,
            "height": 18,
            "foodSpots": ["Bar do Mané", "Hocca Bar"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_ibirapuera_auditorium",
            "name": "Ibirapuera Auditorium",
            "assetName": "ibirapueraAuditorium",
            "description": "A stark white concrete trapezoid in Ibirapuera Park, featuring a 'red tongue' sculpture at the entrance. The back of the stage has a giant door that opens to the park, allowing thousands of people outside to watch performances.",
            "architect": "Oscar Niemeyer",
            "yearBuilt": 2005,
            "address": "Av. Pedro Álvares Cabral, s/n, Ibirapuera, São Paulo - SP",
            "oldUse": "Auditorium",
            "newUse": "Auditorium / Music Venue",
            "buildingStyle": "Modernist",
            "numberOfStories": 3,
            "height": 15,
            "foodSpots": ["Selvagem", "MAM Café"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_japan_house",
            "name": "Japan House São Paulo",
            "assetName": "japanHouse",
            "description": "A striking example of modern adaptive reuse on Paulista Avenue. The facade features a curtain made of Hinoki wood pieces (some 2,000 years old) interlocked by Japanese craftsmen. It serves as a bridge for Japanese technology and art.",
            "architect": "Kengo Kuma",
            "yearBuilt": 2017,
            "address": "Av. Paulista, 52, Bela Vista, São Paulo - SP",
            "oldUse": "Commercial Building",
            "newUse": "Cultural Center",
            "buildingStyle": "Contemporary / Japanese Minimalist",
            "numberOfStories": 3,
            "height": 12,
            "foodSpots": ["Aizomê", "Shin-Zushi"],
            "currency": "BRL (R$)"
        },
        {
            "id": "br_casa_das_rosas",
            "name": "Casa das Rosas",
            "assetName": "casaRosas",
            "description": "One of the few remaining mansions from the era when Paulista Avenue was a residential street for coffee barons. It is a French-style manor house that now functions as a 'space for poetry' and literature, surrounded by a famous rose garden.",
            "architect": "Ramos de Azevedo",
            "yearBuilt": 1935,
            "address": "Av. Paulista, 37, Bela Vista, São Paulo - SP",
            "oldUse": "Private Residence",
            "newUse": "Cultural Center / Poetry Museum",
            "buildingStyle": "Classical French Eclectic",
            "numberOfStories": 2,
            "height": 14,
            "foodSpots": ["Caffè Ristoro", "Tujuína"],
            "currency": "BRL (R$)"
        }
    ]
