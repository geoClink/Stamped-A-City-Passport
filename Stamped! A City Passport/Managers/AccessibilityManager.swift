//
//  File.swift
//  iDiscoverSwiftStudentChallenge
//
//  Created by George Clinkscales on 1/23/26.
//

import Foundation

import SwiftUI

struct HighContrastWrapper {
    let isActive: Bool
    
    func color(_ standard: Color, highVisibility: Color = .primary) -> Color {
        isActive ? highVisibility : standard
    }
    
    var weight: Font.Weight {
        isActive ? .black : .bold
    }
}


