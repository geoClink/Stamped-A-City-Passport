//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/27/26.
//

import Foundation

enum QuestionType: CaseIterable {
    case name
    case style
    case year
    case architect
    case stories

    var prompt: String {
        switch self {
        case .name:
            return "Based on the data, which landmark is this?"
        case .style:
            return "What is the architectural style of this building?"
        case .year:
            return "In what year was this structure completed?"
        case .architect:
            return "Which architect or firm designed this building?"
        case .stories:
            return "How many stories tall is this structure?"
        }
    }

    var voicePrompt: String {
        switch self {
        case .name: return "Speak the name of the landmark..."
        case .style: return "Speak the architectural style..."
        case .year: return "Say the year it was completed..."
        case .architect: return "Speak the architect or firm name..."
        case .stories: return "Say the number of floors..."
        }
    }
}
