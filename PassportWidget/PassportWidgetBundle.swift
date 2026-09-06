//
//  PassportWidgetBundle.swift
//  PassportWidget
//
//  Created by George Clinkscales on 9/5/26.
//

import WidgetKit
import SwiftUI

@main
struct PassportWidgetBundle: WidgetBundle {
    var body: some Widget {
        PassportWidget()
        PassportWidgetControl()
        PassportWidgetLiveActivity()
    }
}
