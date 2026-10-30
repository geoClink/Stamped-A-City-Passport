//
//  CollegeScorecardIDs.swift
//  Stamped! A City Passport
//
//  Each US campus's IPEDS UNITID, the ID the College Scorecard API knows a school by.
//  Taken from the university's Wikidata entry (property P1771) and checked against the
//  Scorecard on 2026-10-29: every ID returned the same school, in the right city and state.
//  The comment is the Scorecard's own name for the school.
//

import Foundation

extension CityLocation.City {
    /// The College Scorecard (IPEDS) ID, or nil for cities and campuses outside the US.
    var scorecardID: Int? {
        guard isCampus, country == .unitedStates else { return nil }
        return Self.scorecardIDs[self]
    }

    /// US campus → IPEDS UNITID. Main campuses only ("Penn State" is University Park).
    static let scorecardIDs: [CityLocation.City: Int] = [
        .utAustin: 228778,            // The University of Texas at Austin
        .floridaSouthern: 134079,     // Florida Southern College
        .bostonCollege: 164924,       // Boston College
        .clemson: 217882,             // Clemson University
        .duke: 198419,                // Duke University
        .floridaState: 134097,        // Florida State University
        .georgiaTech: 139755,         // Georgia Institute of Technology-Main Campus
        .uLouisville: 157289,         // University of Louisville
        .uMiami: 135726,              // University of Miami
        .ncState: 199193,             // North Carolina State University at Raleigh
        .uncChapelHill: 199120,       // University of North Carolina at Chapel Hill
        .uPittsburgh: 215293,         // University of Pittsburgh-Pittsburgh Campus
        .smu: 228246,                 // Southern Methodist University
        .syracuse: 196413,            // Syracuse University
        .virginiaTech: 233921,        // Virginia Polytechnic Institute and State University
        .wakeForest: 199847,          // Wake Forest University
        .uArizona: 104179,            // University of Arizona
        .arizonaState: 104151,        // Arizona State University Campus Immersion
        .byu: 230038,                 // Brigham Young University
        .uHouston: 225511,            // University of Houston
        .iowaState: 153603,           // Iowa State University
        .uKansas: 155317,             // University of Kansas
        .kansasState: 155399,         // Kansas State University
        .oklahomaState: 207388,       // Oklahoma State University-Main Campus
        .texasTech: 229115,           // Texas Tech University
        .westVirginia: 238032,        // West Virginia University
        .baylor: 223232,              // Baylor University
        .uCincinnati: 201885,         // University of Cincinnati-Main Campus
        .cuBoulder: 126614,           // University of Colorado Boulder
        .tcu: 228875,                 // Texas Christian University
        .ucf: 132903,                 // University of Central Florida
        .uUtah: 230764,               // University of Utah
        .uIllinois: 145637,           // University of Illinois Urbana-Champaign
        .uIndiana: 151351,            // Indiana University-Bloomington
        .uIowa: 153658,               // University of Iowa
        .uMaryland: 163286,           // University of Maryland-College Park
        .michiganState: 171100,       // Michigan State University
        .uMinnesota: 174066,          // University of Minnesota-Twin Cities
        .uNebraska: 181464,           // University of Nebraska-Lincoln
        .northwestern: 147767,        // Northwestern University
        .ohioState: 204796,           // Ohio State University-Main Campus
        .pennState: 214777,           // Pennsylvania State University-Main Campus
        .purdue: 243780,              // Purdue University-Main Campus
        .rutgers: 186380,             // Rutgers University-New Brunswick
        .uWisconsin: 240444,          // University of Wisconsin-Madison
        .uOregon: 209551,             // University of Oregon
        .uSouthernCalifornia: 123961, // University of Southern California
        .uAlabama: 100751,            // The University of Alabama
        .uArkansas: 106397,           // University of Arkansas
        .auburn: 100858,              // Auburn University
        .uFlorida: 134130,            // University of Florida
        .uGeorgia: 139959,            // University of Georgia
        .lsu: 159391,                 // Louisiana State University and Agricultural & Mechanical College
        .olemiss: 176017,             // University of Mississippi
        .mizzou: 178396,              // University of Missouri-Columbia
        .uOklahoma: 207500,           // University of Oklahoma-Norman Campus
        .uSouthCarolina: 218663,      // University of South Carolina-Columbia
        .vanderbilt: 221999,          // Vanderbilt University
        .uKentucky: 157085,           // University of Kentucky
        .msState: 176080,             // Mississippi State University
        .uTennessee: 221759,          // The University of Tennessee-Knoxville
        .texasAM: 228723,             // Texas A&M University-College Station
        .yale: 130794,                // Yale University
        .harvard: 166027,             // Harvard University
        .mit: 166683,                 // Massachusetts Institute of Technology
        .princeton: 186131,           // Princeton University
        .cornell: 190415,             // Cornell University
        .columbia: 190150,            // Columbia University in the City of New York
        .upenn: 215062,               // University of Pennsylvania
        .brown: 217156,               // Brown University
        .dartmouth: 182670,           // Dartmouth College
        .georgetown: 131496,          // Georgetown University
        .uChicago: 144050,            // University of Chicago
        .notreDame: 152080,           // University of Notre Dame
        .uMichigan: 170976,           // University of Michigan-Ann Arbor
        .illinoisTech: 145725,        // Illinois Institute of Technology
        .uVirginia: 234076,           // University of Virginia-Main Campus
        .stanford: 243744,            // Stanford University
        .berkeley: 110635,            // University of California-Berkeley
        .ucla: 110662,                // University of California-Los Angeles
        .uWashington: 236948,         // University of Washington-Seattle Campus
        // Added with the 11 new campuses on 2026-10-29. These IDs and names are from Wikidata
        // (P1771) only: they haven't been checked against the Scorecard yet, which needs the key.
        .wayneState: 172644,          // Wayne State University
        .westernMichigan: 172699,     // Western Michigan University
        .grandValleyState: 170082,    // Grand Valley State University
        .caltech: 110404,             // California Institute of Technology
        .johnsHopkins: 162928,        // Johns Hopkins University
        .rice: 227757,                // Rice University
        .emory: 139658,               // Emory University
        .tulane: 160755,              // Tulane University
        .nyu: 193900,                 // New York University
        .carnegieMellon: 211440,      // Carnegie Mellon University
        .washU: 179867,               // Washington University in St. Louis
    ]
}
