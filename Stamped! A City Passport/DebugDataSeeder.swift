// DebugDataSeeder.swift
// TEMPORARY — for App Store screenshots only.
// DELETE THIS FILE before submitting to App Store.

import Foundation

enum DebugDataSeeder {
    private static let visitedIDs: [String] = [
        // Bath — MASTERED (15/15)
        "uk_roman_baths", "uk_royal_crescent", "uk_bath_abbey",
        "uk_pulteney_bridge", "uk_thermae_bath_spa", "uk_holburne_museum",
        "uk_the_circus", "uk_prior_park", "uk_assembly_rooms",
        "uk_guildhall", "uk_beckfords_tower", "uk_theatre_royal",
        "uk_milsom_place", "uk_victoria_art_gallery", "uk_green_park_station",

        // Detroit — MASTERED (31/31)
        "usa_apple_downtown_detroit", "detroit_first_national", "detroit_the_z",
        "detroit_packard_plant", "detroit_one_kennedy", "detroit_mcgregor_center",
        "detroit_book_tower", "detroit_ren_cen", "detroit_hudson",
        "detroit_guardian", "detroit_michigan_central", "detroit_ally_center",
        "detroit_fisher_building", "detroit_fox_theatre", "detroit_penobscot",
        "detroit_dia", "detroit_cadillac_place", "detroit_masonic_temple",
        "detroit_lafayette_towers", "detroit_david_stott", "detroit_david_whitney",
        "detroit_book_cadillac", "detroit_buhl_building", "detroit_dpl_main",
        "detroit_vinton", "detroit_cadillac_tower", "detroit_fort_shelby",
        "detroit_united_artists", "detroit_fillmore", "detroit_motown_museum",
        "detroit_wright_kay",

        // Los Angeles — MASTERED (15/15)
        "la_disney_hall", "glbl_apple_tower_theatre", "la_griffith_observatory",
        "la_bradbury_building", "la_lax_theme", "la_hollyhock_house",
        "la_getty_center", "la_wilshire_grand", "la_eastern_columbia",
        "la_stahl_house", "la_academy_museum", "la_union_station",
        "la_capitol_records", "la_binoculars_building", "la_apple_the_grove",

        // New Orleans — MASTERED (15/15)
        "nola_st_louis_cathedral", "nola_apple_lakeside", "nola_the_sazerac_house",
        "nola_preservation_hall", "nola_hotel_monteleone", "nola_superdome",
        "nola_custom_house", "nola_commanders_palace", "nola_old_ursuline_convent",
        "nola_gallier_hall", "nola_contemporary_arts_center", "nola_pitot_house",
        "nola_hancock_whitney", "nola_cornstalk_hotel", "nola_wwii_museum",

        // Las Vegas — MASTERED (11/11)
        "lv_luxor", "lv_strator", "lv_bellagio", "lv_sphere", "lv_caesars",
        "lv_lou_ruvo", "lv_vegas_city_hall", "lv_circus_circus",
        "lv_new_york", "lv_encore", "lv_apple_forum_shops",

        // Singapore — MASTERED (12/12)
        "sg_marina_bay_sands", "sg_artscience_museum", "sg_the_interlace",
        "sg_jewel_changi", "sg_victoria_theatre", "sg_parkroyal_pickering",
        "sg_the_hive", "sg_duxton_plain", "sg_old_hill_street",
        "sg_capitaspring", "sg-apple-mbs", "sg-apple-amk",

        // Seattle — MASTERED (11/11)
        "sea_space_needle", "sea_central_library", "sea_amazon_spheres",
        "sea_mopop", "sea_columbia_center", "sea_rainier_tower",
        "sea_pike_place", "sea_smith_tower", "sea_bullitt_center",
        "sea_pacific_science_arches", "sea_apple_u_village",

        // Orlando — MASTERED (11/11)
        "orl_cinderella_castle", "orl_spaceship_earth", "orl_dr_phillips_center",
        "orl_lake_eola_pagoda", "orl_orlando_public_library", "orl_creative_village_ea",
        "orl_suntrust_center", "orl_citrus_bowl", "orl_science_center",
        "orl_the_wheel", "orl_apple_millenia",

        // Dubai — MASTERED (9/9)
        "dxb_burj_al_arab", "dxb_museum_future", "dxb_atlantis_royal",
        "dxb_cayan_tower", "dxb_dubai_frame", "dxb_jumeirah_emirates",
        "dxb_opus", "dxb_index_tower", "dxb_etihad_museum",

        // Portland — MASTERED (10/10)
        "pdx_portland_building", "pdx_pioneer_courthouse", "pdx_big_pink",
        "pdx_wells_fargo", "pdx_pae_living", "pdx_union_station",
        "pdx_commonwealth_building", "pdx_moda_center", "pdx_custom_house",
        "pdx_tilikum_crossing",

        // Chicago — partial (~60%)
        "chi-01", "us_apple_michigan_ave", "chi-02", "chi-03", "chi-04",
        "chi-05", "chi-06", "chi-07", "chi-08", "chi-09",

        // Washington D.C. — partial (~55%)
        "dc-01", "glbl_apple_carnegie_library", "dc-02", "dc-03", "dc-04", "dc-05",

        // Miami — partial (~40%)
        "mia-01", "mia-02", "mia-03", "mia-04", "mia_1111_lincoln",

        // Boston — partial (~30%)
        "bos-01", "bos-02", "bos-03", "bos-04",

        // Denver — a few
        "den-01", "den-02", "den-03",

        // Atlanta — a few
        "atl-01", "atl-02", "atl_westin_peachtree",
    ]

    private static let notes: [String: String] = [
        "uk_roman_baths": "The thermal spring water is genuinely 46°C — you can feel the heat rising from the Great Bath. Go first thing when it opens before the tour groups arrive.",
        "uk_royal_crescent": "114 Ionic columns along the crescent. The scale only hits you when you're standing directly in front of it. No. 1 has a great museum inside.",
        "uk_bath_abbey": "Fan vaulting is stunning in the afternoon light. The angels on the west facade are easy to miss — look up at the ladders carved into the towers.",
        "la_bradbury_building": "Used in Blade Runner. The light well in the center is everything — wrought iron balconies and glazed roof. Worth the $5 entry just to stand inside.",
        "detroit_fisher_building": "The arcade ceiling is pure gold leaf Art Deco. Most people walk past it — go inside and look up. Free to enter.",
        "sg_jewel_changi": "The HSBC Rain Vortex falls 40m indoors. Best viewed from the upper floors of the mall looking down. Airport alone is worth a layover for.",
    ]

    /// Call this once after GlobalProgressManager is initialised.
    /// Updates both UserDefaults and the live in-memory manager so the UI reflects
    /// the seed data immediately without needing an app restart.
    @MainActor
    static func seedIfNeeded() {
        let manager = GlobalProgressManager.shared

        // Only seed when there's no real data yet
        guard manager.visitedIDs.isEmpty else { return }

        // Update live in-memory state — didSet writes through to UserDefaults automatically
        manager.visitedIDs = Set(visitedIDs)

        // Spread visit dates across the past year
        let now = Date()
        for (index, id) in visitedIDs.enumerated() {
            let daysAgo = Double(index * 3 + 1)
            manager.visitDates[id] = now.addingTimeInterval(-daysAgo * 86400)
        }

        // Write notes directly and persist
        for (id, note) in notes {
            manager.saveNote(note, for: id)
        }

        print("[DebugDataSeeder] ✅ Seeded \(visitedIDs.count) visited buildings and \(notes.count) notes")
    }
}
