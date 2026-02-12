import Foundation
import HijriCalendarCore

enum HijriDateDisplay {
    static func formatted(_ hijriDate: HijriDate) -> String {
        let monthName = monthName(for: hijriDate.month)
        if let year = hijriDate.year {
            return "\(hijriDate.day) \(monthName) \(year)"
        }
        return "\(hijriDate.day) \(monthName)"
    }

    static func monthName(for month: Int) -> String {
        switch month {
        case 1: return "Muharram"
        case 2: return "Safar"
        case 3: return "Rabi al-Awwal"
        case 4: return "Rabi al-Thani"
        case 5: return "Jumada al-Ula"
        case 6: return "Jumada al-Akhira"
        case 7: return "Rajab"
        case 8: return "Shaban"
        case 9: return "Ramadan"
        case 10: return "Shawwal"
        case 11: return "Dhul Qidah"
        case 12: return "Dhul Hijjah"
        default: return "Month \(month)"
        }
    }
}
