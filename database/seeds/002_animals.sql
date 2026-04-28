-- =====================================================
-- SEED DATA: ANIMALS TABLE
-- Bwindi Wildlife Species
-- =====================================================

-- Mountain Gorilla
INSERT INTO animals (animal_id, name, scientific_name, description, conservation_status, habitat, diet, lifespan, fun_facts)
VALUES (
    gen_random_uuid(),
    'Mountain Gorilla',
    'Gorilla beringei beringei',
    'The mountain gorilla is one of the two subspecies of eastern gorilla. They have longer hair and shorter arms than their lowland cousins. Mountain gorillas are critically endangered, with approximately 1,063 individuals remaining in the wild, half of which live in Bwindi Impenetrable National Park.',
    'endangered',
    'Montane forests at elevations of 2,200-4,300 meters',
    'Herbivore (leaves, stems, bark, roots, flowers, fruit)',
    '35-40 years',
    ARRAY['Share 98.3% of human DNA', 'Can laugh, grieve, and use tools', 'Live in family groups of 5-30 led by a silverback male', 'Each gorilla has a unique nose print']
);

-- African Elephant
INSERT INTO animals (animal_id, name, scientific_name, description, conservation_status, habitat, diet, lifespan, fun_facts)
VALUES (
    gen_random_uuid(),
    'African Elephant',
    'Loxodonta africana',
    'The African elephant is the largest land mammal on Earth. They are characterized by their large ears, which help regulate body temperature, and their long tusks, which are actually elongated incisor teeth.',
    'vulnerable',
    'Savannas, forests, deserts, and marshes',
    'Herbivore (grasses, fruits, roots, bark)',
    '60-70 years',
    ARRAY['Elephants can''t jump', 'Pregnancy lasts 22 months (longest of any mammal)', 'Trunk has over 40,000 muscles', 'Can recognize themselves in mirrors']
);

-- African Fish Eagle
INSERT INTO animals (animal_id, name, scientific_name, description, conservation_status, habitat, diet, lifespan, fun_facts)
VALUES (
    gen_random_uuid(),
    'African Fish Eagle',
    'Haliaeetus vocifer',
    'The African fish eagle is a large bird of prey found throughout sub-Saharan Africa near large bodies of water. It is known for its distinctive call, which has become synonymous with the African wilderness.',
    'least_concern',
    'Lakes, rivers, and wetlands',
    'Carnivore (fish, waterbirds, carrion)',
    '12-15 years',
    ARRAY['Call is often used as a symbol of Africa', 'Can spot fish from over 500 meters away', 'Has a wingspan of up to 2.4 meters']
);

-- Great Blue Turaco
INSERT INTO animals (animal_id, name, scientific_name, description, conservation_status, habitat, diet, lifespan, fun_facts)
VALUES (
    gen_random_uuid(),
    'Great Blue Turaco',
    'Corythaeola cristata',
    'The great blue turaco is the largest species of turaco, found in the forests of Central and West Africa. It has striking blue and green plumage, a prominent crest, and a bright yellow beak.',
    'least_concern',
    'Lowland and montane forests',
    'Frugivore (primarily figs and other fruits)',
    '10-15 years',
    ARRAY['Can climb tree trunks like parrots', 'Has a distinctive ''cow-cow-cow'' call', 'Plays important role in seed dispersal']
);