//
//  Schedule.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import Foundation

struct Schedule: Identifiable, Codable {
    var id = UUID()
    var title: String
    var schedule: String
    var status: String
    var isActive: Bool
    var cloudKitRecordID: String?
    
    init(title: String, schedule: String, status: String, isActive: Bool) {
        self.id = UUID()
        self.title = title
        self.schedule = schedule
        self.status = status
        self.isActive = isActive
    }
}

enum ScheduleType: String, CaseIterable {
    case recurring = "Recurring"
    case oneTime = "One-time"
}
