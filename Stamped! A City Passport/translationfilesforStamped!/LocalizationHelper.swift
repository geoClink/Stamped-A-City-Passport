//
//  LocalizationHelper.swift
//  Stamped! A City Passport
//
//  Drop this file into your project. It provides type-safe access to all
//  localised strings and fixes the hardcoded issues identified across the app.
//

import Foundation
import SwiftUI

// MARK: - Centralised String Access
// Use these instead of hardcoded strings throughout the app.

enum L {

    // MARK: Onboarding
    enum Onboarding {
        static let skip = String(localized: "onboarding.button.skip")
        static let next = String(localized: "onboarding.button.next")
        static let getStarted = String(localized: "onboarding.button.getStarted")
        static let skipAccessibilityLabel = String(localized: "onboarding.accessibility.skip.label")
        static let skipAccessibilityHint = String(localized: "onboarding.accessibility.skip.hint")

        static func stepTitle(_ index: Int) -> String {
            String(localized: "onboarding.step\(index + 1).title")
        }
        static func stepDescription(_ index: Int) -> String {
            String(localized: "onboarding.step\(index + 1).description")
        }
    }

    // MARK: City List
    enum CityList {
        static let searchPrompt = String(localized: "cityList.search.prompt")
        static let passportButton = String(localized: "cityList.passport.button")
        static let welcomeTitle = String(localized: "cityList.welcome.title")
        static let welcomeBody = String(localized: "cityList.welcome.body")
        static let ipadHint = String(localized: "cityList.welcome.ipad.hint")
    }

    // MARK: City Detail
    enum CityDetail {
        static func explored(_ percent: Int) -> String {
            String(format: String(localized: "cityDetail.explored"), percent)
        }
        static let explorationProgress = String(localized: "cityDetail.explorationProgress")
        static func masteryLevel(_ tier: String) -> String {
            String(format: String(localized: "cityDetail.masteryLevel"), tier)
        }
        static let resetProgress = String(localized: "cityDetail.toolbar.resetProgress")
        static let resetQuiz = String(localized: "cityDetail.toolbar.resetQuiz")
        static let resetStamps = String(localized: "cityDetail.toolbar.resetStamps")
        static let resetPhotos = String(localized: "cityDetail.toolbar.resetPhotos")
        static let resetEverything = String(localized: "cityDetail.toolbar.resetEverything")
        static let confirmReset = String(localized: "cityDetail.alert.confirmReset")
        static let yesReset = String(localized: "cityDetail.alert.yesReset")
        static let cancel = String(localized: "cityDetail.alert.cancel")
    }

    // MARK: Mastery Tiers
    enum Mastery {
        static let tourist = String(localized: "mastery.tourist")
        static let explorer = String(localized: "mastery.explorer")
        static let urbanInsider = String(localized: "mastery.urbanInsider")
        static let localLegend = String(localized: "mastery.localLegend")
        static let masterCollector = String(localized: "mastery.masterCollector")
    }

    // MARK: Discovery Ranks
    enum Rank {
        static let tourist = String(localized: "rank.tourist")
        static let urbanExplorer = String(localized: "rank.urbanExplorer")
        static let architectureCritic = String(localized: "rank.architectureCritic")
        static let cityHistorian = String(localized: "rank.cityHistorian")
        static let grandMaster = String(localized: "rank.grandMaster")
    }

    // MARK: Landmarks
    enum Landmarks {
        static let header = String(localized: "landmarks.header")
        static func sectionLabel(_ city: String) -> String {
            String(format: String(localized: "landmarks.accessibility.sectionLabel"), city)
        }
        static func visited(_ name: String) -> String {
            String(format: String(localized: "landmarks.row.visited"), name)
        }
        static func notVisited(_ name: String) -> String {
            String(format: String(localized: "landmarks.row.notVisited"), name)
        }
        static func architect(_ name: String) -> String {
            String(format: String(localized: "landmarks.row.architect"), name)
        }
        static let hint = String(localized: "landmarks.row.hint")
    }

    // MARK: Quiz
    enum Quiz {
        static let title = String(localized: "quiz.title")
        static let improveScore = String(localized: "quiz.improveScore")
        static let mastered = String(localized: "quiz.mastered")
        static let subtitleStart = String(localized: "quiz.subtitle.start")
        static let subtitleImprove = String(localized: "quiz.subtitle.improve")
        static let subtitleMastered = String(localized: "quiz.subtitle.mastered")
        static let hint = String(localized: "quiz.accessibility.hint")
        static func accessibilityLabel(title: String, subtitle: String, score: Int) -> String {
            String(format: String(localized: "quiz.accessibility.label"), title, subtitle, score)
        }
    }

    // MARK: Travel Info
    enum Travel {
        static let header = String(localized: "travel.header")
        static let language = String(localized: "travel.language")
        static let airport = String(localized: "travel.airport")
        static let transportation = String(localized: "travel.transportation")
        static let currency = String(localized: "travel.currency")
        static let localTransit = String(localized: "travel.localTransit")
        static let cityTransit = String(localized: "travel.cityTransit")
        static let mainAirport = String(localized: "travel.mainAirport")
        static func greeting(_ text: String) -> String {
            String(format: String(localized: "travel.greeting"), text)
        }
    }

    // MARK: Currency
    enum Currency {
        static func homeLabel(_ code: String) -> String {
            String(format: String(localized: "currency.home.label"), code)
        }
        static func localLabel(_ code: String) -> String {
            String(format: String(localized: "currency.local.label"), code)
        }
        static let disclaimer = String(localized: "currency.disclaimer")
        static let statusLive = String(localized: "currency.status.live")
        static let statusCached = String(localized: "currency.status.cached")
        static let statusOffline = String(localized: "currency.status.offline")
        static let refreshLabel = String(localized: "currency.refresh.label")
        static let refreshHint = String(localized: "currency.refresh.hint")
        static let statusIconLabel = String(localized: "currency.accessibility.statusIcon")
        static let modalTitle = String(localized: "currency.modal.title")
        static let modalProvider = String(localized: "currency.modal.provider")
        static let modalLastUpdated = String(localized: "currency.modal.lastUpdated")
        static let modalNever = String(localized: "currency.modal.never")
        static let modalClose = String(localized: "currency.modal.close")
        static let modalHeader = String(localized: "currency.modal.header")
        static let explainLive = String(localized: "currency.modal.explain.live")
        static let explainCached = String(localized: "currency.modal.explain.cached")
        static let explainOffline = String(localized: "currency.modal.explain.offline")
    }

    // MARK: Passport
    enum Passport {
        static let title = String(localized: "passport.title")
        static let countries = String(localized: "passport.countries")
        static let done = String(localized: "passport.done")
        static let close = String(localized: "passport.close")
        static let journeyLog = String(localized: "passport.journeyLog")
        static let explorationProgress = String(localized: "passport.explorationProgress")
        static func citiesStamped(_ count: Int) -> String {
            String(format: String(localized: "passport.citiesStamped"), count)
        }
        static let selectCountry = String(localized: "passport.selectCountry")
        static let stats = String(localized: "passport.stats")
    }

    // MARK: Stamp
    enum Stamp {
        static let passportStamped = String(localized: "stamp.passportStamped")
        static func completed(_ date: String) -> String {
            String(format: String(localized: "stamp.completed"), date)
        }
        static let didYouKnow = String(localized: "stamp.didYouKnow")
        static func accessibilityLabel(_ city: String) -> String {
            String(format: String(localized: "stamp.accessibility.label"), city)
        }
        static func accessibilityValue(date: String, fact: String) -> String {
            String(format: String(localized: "stamp.accessibility.value"), date, fact)
        }
    }

    // MARK: Celebration
    enum Celebration {
        static let cityExplored = String(localized: "celebration.cityExplored")
        static let addToPassport = String(localized: "celebration.addToPassport")
        static func accessibility(_ city: String) -> String {
            String(format: String(localized: "celebration.accessibility"), city)
        }
    }

    // MARK: Passport View
    enum PassportView {
        static let officialStatus = String(localized: "passportView.officialStatus")
        static let complete = String(localized: "passportView.complete")
        static func landmarksDiscovered(visited: Int, total: Int) -> String {
            String(format: String(localized: "passportView.landmarksDiscovered"), visited, total)
        }
        static func collected(visited: Int, total: Int) -> String {
            String(format: String(localized: "passportView.collected"), visited, total)
        }
        static let beginJourney = String(localized: "passportView.beginJourney")
        static let beginJourneyBody = String(localized: "passportView.beginJourney.body")
        static func verifiedOn(_ date: String) -> String {
            String(format: String(localized: "passportView.verifiedOn"), date)
        }
        static let shareAchievement = String(localized: "passportView.shareAchievement")
        static let dismiss = String(localized: "passportView.dismiss")
        static func shareText(_ city: String) -> String {
            String(format: String(localized: "passportView.shareText"), city)
        }
        static func masterOf(_ city: String) -> String {
            String(format: String(localized: "passportView.masterOf"), city)
        }
    }

    // MARK: Itinerary
    enum Itinerary {
        static let header = String(localized: "itinerary.header")
        static func day(_ n: Int) -> String {
            String(format: String(localized: "itinerary.day"), n)
        }
        static func stops(_ n: Int) -> String {
            String(format: String(localized: "itinerary.stops"), n)
        }
        static func totalTime(hours: Int, mins: Int) -> String {
            String(format: String(localized: "itinerary.totalTime"), hours, mins)
        }
        static func walk(_ mins: Int) -> String {
            String(format: String(localized: "itinerary.walk"), mins)
        }
        static func transit(_ mins: Int) -> String {
            String(format: String(localized: "itinerary.transit"), mins)
        }
        static let startsAt = String(localized: "itinerary.startsAt")
        static let lunchStop = String(localized: "itinerary.lunchStop")
        static func nearBuilding(_ name: String) -> String {
            String(format: String(localized: "itinerary.nearBuilding"), name)
        }
        static let timeline = String(localized: "itinerary.timeline")
        static let appleIntelligence = String(localized: "itinerary.appleIntelligence")
        static let aiUnavailable = String(localized: "itinerary.aiUnavailable")
        static let loading = String(localized: "itinerary.loading")
        static let errorTitle = String(localized: "itinerary.error.title")
        static let retry = String(localized: "itinerary.error.retry")
        static func stopsByArchitect(count: Int, architect: String) -> String {
            String(format: String(localized: "itinerary.stopsByArchitect"), count, architect)
        }
    }

    // MARK: Eras
    enum Era {
        static let medieval = String(localized: "era.medieval")
        static let renaissance = String(localized: "era.renaissance")
        static let baroque = String(localized: "era.baroque")
        static let neoclassical = String(localized: "era.neoclassical")
        static let victorian = String(localized: "era.victorian")
        static let artDeco = String(localized: "era.artDeco")
        static let modernist = String(localized: "era.modernist")
        static let postmodern = String(localized: "era.postmodern")
        static let contemporary = String(localized: "era.contemporary")
    }
}

// MARK: - Localised Continent Names
// Add this computed property to CityLocation.Continent in Model.swift
// (shown here for reference — move into Model.swift)
extension CityLocation.Continent {
    var localizedName: String {
        switch self {
        case .africa:       return String(localized: "continent.africa")
        case .asia:         return String(localized: "continent.asia")
        case .europe:       return String(localized: "continent.europe")
        case .northAmerica: return String(localized: "continent.northAmerica")
        case .southAmerica: return String(localized: "continent.southAmerica")
        case .oceania:      return String(localized: "continent.oceania")
        }
    }
}

// MARK: - Localised Mastery Tiers
// Replace the hardcoded strings in VisitManager.getMastery()
extension GlobalProgressManager {
    func localizedMastery(for buildings: [Building]) -> (tier: String, color: SwiftUI.Color, progress: Double, count: Int) {
        let result = getMastery(for: buildings)
        let localizedTier: String
        switch result.tier {
        case "Tourist":           localizedTier = L.Mastery.tourist
        case "Explorer":          localizedTier = L.Mastery.explorer
        case "Urban Insider":     localizedTier = L.Mastery.urbanInsider
        case "Local Legend":      localizedTier = L.Mastery.localLegend
        case "Master Collector":  localizedTier = L.Mastery.masterCollector
        default:                  localizedTier = result.tier
        }
        return (localizedTier, result.color, result.progress, result.count)
    }
}

// MARK: - Localised Discovery Ranks
// Replace discoveryRank in PassportView-ViewModel.swift
func localizedDiscoveryRank(percent: Double) -> String {
    switch percent {
    case 0..<0.1:  return L.Rank.tourist
    case 0.1..<0.4: return L.Rank.urbanExplorer
    case 0.4..<0.7: return L.Rank.architectureCritic
    case 0.7..<0.9: return L.Rank.cityHistorian
    default:        return L.Rank.grandMaster
    }
}

// MARK: - Localised Era Names
// Replace the switch in BasicDaySection.dominantEra
func localizedEra(for averageYear: Int) -> String {
    switch averageYear {
    case ..<1400:      return L.Era.medieval
    case 1400..<1600:  return L.Era.renaissance
    case 1600..<1750:  return L.Era.baroque
    case 1750..<1830:  return L.Era.neoclassical
    case 1830..<1900:  return L.Era.victorian
    case 1900..<1940:  return L.Era.artDeco
    case 1940..<1970:  return L.Era.modernist
    case 1970..<2000:  return L.Era.postmodern
    default:           return L.Era.contemporary
    }
}

// MARK: - Localised Arrival Time (fixes AM/PM for 24hr locales)
// Replace formattedArrivalTime in ItineraryService.swift
func localizedArrivalTime(offsetMins: Int, startHour: Int = 9) -> String {
    let totalMins = startHour * 60 + offsetMins
    let hour = (totalMins / 60) % 24
    let minute = totalMins % 60
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let cal = Calendar.current
    guard let date = cal.date(from: components) else {
        return "\(hour):\(String(format: "%02d", minute))"
    }
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
}

// MARK: - Localised Speech Recognition
// Replace the hardcoded locale in SpeechManager.swift:
// private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

// MARK: - Building Detail
extension L {
    enum Building {
        static let capturePhoto = String(localized: "building.capturePhoto")
        static let historicalSignificance = String(localized: "building.historicalSignificance")
        static let buildingInfo = String(localized: "building.buildingInfo")
        static let technicalSpecs = String(localized: "building.technicalSpecs")
        static let localFlavors = String(localized: "building.localFlavors")
        static let nearby = String(localized: "building.nearby")
        static let location = String(localized: "building.location")
        static let built = String(localized: "building.built")
        static let height = String(localized: "building.height")
        static let stories = String(localized: "building.stories")
        static func designedBy(_ architect: String) -> String {
            String(format: String(localized: "building.designedBy"), architect)
        }
        static let markVisited = String(localized: "building.markVisited")
        static let visited = String(localized: "building.visited")
        static let deletePhotoTitle = String(localized: "building.deletePhoto.title")
        static let deletePhotoMessage = String(localized: "building.deletePhoto.message")
        static let deletePhotoConfirm = String(localized: "building.deletePhoto.confirm")
        static let mapErrorTitle = String(localized: "building.map.errorTitle")
        static let mapErrorMessage = String(localized: "building.map.errorMessage")
        static let mapOK = String(localized: "building.map.ok")
    }

    // MARK: - Settings
    enum Settings {
        static let title = String(localized: "settings.title")
        static let experience = String(localized: "settings.experience")
        static let resetProgress = String(localized: "settings.resetProgress")
        static let maintenance = String(localized: "settings.maintenance")
        static let back = String(localized: "settings.back")
        static let selectSetting = String(localized: "settings.selectSetting")
        static let appExperience = String(localized: "settings.appExperience")
        static let measurementUnits = String(localized: "settings.measurementUnits")
        static let unitSystem = String(localized: "settings.unitSystem")
        static let meters = String(localized: "settings.meters")
        static let feet = String(localized: "settings.feet")
        static let soundEffects = String(localized: "settings.soundEffects")
        static let haptics = String(localized: "settings.haptics")
        static let highContrast = String(localized: "settings.highContrast")
        static let reduceMotion = String(localized: "settings.reduceMotion")
        static let offlineReady = String(localized: "settings.offlineReady")
        static let offlineReadyBody = String(localized: "settings.offlineReady.body")
        static let preview = String(localized: "settings.preview")
        static let testMotion = String(localized: "settings.testMotion")
        static let testSound = String(localized: "settings.testSound")
        static let resetAllContent = String(localized: "settings.resetAllContent")
        static let version = String(localized: "settings.version")
        static let resetFirstTitle = String(localized: "settings.reset.firstAlert.title")
        static let resetFirstMessage = String(localized: "settings.reset.firstAlert.message")
        static let resetFirstContinue = String(localized: "settings.reset.firstAlert.continue")
        static let resetFinalTitle = String(localized: "settings.reset.finalAlert.title")
        static let resetFinalMessage = String(localized: "settings.reset.finalAlert.message")
        static let resetFinalConfirm = String(localized: "settings.reset.finalAlert.confirm")
        static let resetFinalCancel = String(localized: "settings.reset.finalAlert.cancel")
    }

    // MARK: - Quiz Extra
    enum QuizExtra {
        static func navigationTitle(_ city: String) -> String {
            String(format: String(localized: "quiz.navigation.title"), city)
        }
        static let exit = String(localized: "quiz.exit")
        static let fieldInquiry = String(localized: "quiz.fieldInquiry")
        static let fieldData = String(localized: "quiz.fieldData")
        static func log(current: Int, total: Int) -> String {
            String(format: String(localized: "quiz.log"), current, total)
        }
        static func score(_ n: Int) -> String {
            String(format: String(localized: "quiz.score"), n)
        }
        static let identificationRequired = String(localized: "quiz.identificationRequired")
        static let labelStyle = String(localized: "quiz.label.style")
        static let labelYear = String(localized: "quiz.label.year")
        static let labelStories = String(localized: "quiz.label.stories")
        static let labelArchitect = String(localized: "quiz.label.architect")
        static let classified = String(localized: "quiz.classified")
        static let returnToCity = String(localized: "quiz.returnToCity")
        static let requestHint = String(localized: "quiz.requestHint")
        static let concealHint = String(localized: "quiz.concealHint")
        static let voiceAnswer = String(localized: "quiz.voiceAnswer")
        static let listening = String(localized: "quiz.listening")
        static let voicePrompt = String(localized: "quiz.voicePrompt")
        static func streakRow(_ n: Int) -> String {
            String(format: String(localized: "quiz.streakRow"), n)
        }
        static func floors(_ n: Int) -> String {
            String(format: String(localized: "quiz.floors"), n)
        }
        static let correct = String(localized: "quiz.correct")
        static func incorrect(_ answer: String) -> String {
            String(format: String(localized: "quiz.incorrect"), answer)
        }
    }

    // MARK: - Question Prompts
    enum Question {
        static let name = String(localized: "question.name")
        static let style = String(localized: "question.style")
        static let year = String(localized: "question.year")
        static let architect = String(localized: "question.architect")
        static let stories = String(localized: "question.stories")
    }

    // MARK: - Hints
    enum Hint {
        static func name(city: String, style: String) -> String {
            String(format: String(localized: "hint.name"), city, style)
        }
        static func architect(decade: String) -> String {
            String(format: String(localized: "hint.architect"), decade)
        }
        static func yearPrewar(architect: String) -> String {
            String(format: String(localized: "hint.year.prewar"), architect)
        }
        static func yearModernist(architect: String) -> String {
            String(format: String(localized: "hint.year.modernist"), architect)
        }
        static func style(year: Int) -> String {
            String(format: String(localized: "hint.style"), year)
        }
        static func stories(style: String, decade: String) -> String {
            String(format: String(localized: "hint.stories"), style, decade)
        }
    }
}
