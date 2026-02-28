//
//  File.swift
//  Stamped!
//
//  Created by George Clinkscales on 1/15/26.
//

import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
class GlobalProgressManager: ObservableObject {
    static let shared = GlobalProgressManager()
    
    // MARK: - Data Storage
    
    @Published var visitedIDs: Set<String> = [] {
        didSet { save() }
    }
    
    @Published var userImages: [String: UIImage] = [:]
    
    private let saveKey = "GlobalVisitedBuildingsKey"

    private init() {
        if let savedData = UserDefaults.standard.array(forKey: saveKey) as? [String] {
            self.visitedIDs = Set(savedData)
        } else {
            self.visitedIDs = [
                        "sf-01", "sf-02", "sf-03", "sf-04", "sf-05",
                        "sf-06", "sf-07", "sf-08", "sf-09", "sf-10",
                         "sf_mira_tower", "sf_hyatt_regency",
                        "sf_grace_cathedral", "sf-12", "sf-14",
                        "sf-17", "sf-16", "sf-20", "sf-15","sf-19", "sf-18","sf-13", "sf-11"
                    ]
            save()
        }
        
        loadImagesFromDisk()
    }

    // MARK: - Persistent Image Logic
    
    private func loadImagesFromDisk() {
        let documents = getDocumentsDirectory()
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
            
            for url in fileURLs where url.pathExtension == "jpg" {
                // Extracts "BuildingName" from "BuildingName.jpg"
                let buildingID = url.deletingPathExtension().lastPathComponent
                
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    self.userImages[buildingID] = image
                }
            }
        } catch {
            print("Error scanning for saved images: \(error)")
        }
    }
    
    func saveImage(_ image: UIImage, for buildingID: String) {
        userImages[buildingID] = image
        
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        
        do {
            try data.write(to: url)
            print("Successfully saved image for \(buildingID) to disk.")
        } catch {
            print("Error writing image to disk: \(error)")
        }
    }

    func loadImage(for buildingID: String) -> UIImage? {
        if let cached = userImages[buildingID] { return cached }
        
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            userImages[buildingID] = image
            return image
        }
        return nil
    }
    
    func deleteImage(for buildingID: String) {
        userImages.removeValue(forKey: buildingID)
        
        let url = getDocumentsDirectory().appendingPathComponent("\(buildingID).jpg")
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Core Progress Logic
    
    func toggleVisit(for buildingID: String, in cityBuildings: [Building]) {
        if visitedIDs.contains(buildingID) {
            visitedIDs.remove(buildingID)
        } else {
            visitedIDs.insert(buildingID)
        }
    }

    func getMastery(for buildings: [Building]) -> (tier: String, color: Color, progress: Double, count: Int) {
        let total = buildings.count
        let visitedCount = buildings.filter { visitedIDs.contains($0.id) }.count
        
        guard total > 0 else { return ("Tourist", .blue, 0.0, 0) }
        let percentage = Double(visitedCount) / Double(total)
        
        switch percentage {
        case 0..<0.25: return ("Tourist", .blue, percentage, visitedCount)
        case 0.25..<0.50: return ("Explorer", .green, percentage, visitedCount)
        case 0.50..<0.75: return ("Urban Insider", .purple, percentage, visitedCount)
        case 0.75..<1.0: return ("Local Legend", Color.adventureOrange, percentage, visitedCount)
        case 1.0: return ("Master Collector", Color(red: 0.85, green: 0.65, blue: 0.13), 1.0, visitedCount)
        default: return ("Tourist", .blue, 0, visitedCount)
        }
    }
    
    func isCityComplete(_ city: CityLocation.City) -> Bool {
        let cityIDs = Set(city.buildings.map { $0.id })
        return cityIDs.isSubset(of: visitedIDs)
    }

    func isVisited(_ id: String) -> Bool {
        visitedIDs.contains(id)
    }

    private func save() {
        UserDefaults.standard.set(Array(visitedIDs), forKey: saveKey)
    }
    
    func resetAllProgress() {
        visitedIDs.removeAll()
        userImages.removeAll()
        
        let documents = getDocumentsDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "jpg" {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        UserDefaults.standard.set(0, forKey: "TotalStampsCount")
    }
}
