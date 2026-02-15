//
//  Logger.swift
//  OpenLine
//
//  Created by Andrew Shea on 1/27/26.
//
import Foundation
import os.log

final class Logger {
    static let shared = Logger()

    private let logger: os.Logger
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.shea.OpenLine"

    private init() {
        logger = os.Logger(subsystem: subsystem, category: "OpenLine")
    }

    // MARK: - Log Levels

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        logger.debug("\(context) \(message)")
        #endif
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        logger.info("\(context) \(message)")
        #else
        logger.info("\(message)")
        #endif
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        logger.warning("\(context) \(message)")
        #else
        logger.warning("\(message)")
        #endif
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        logger.error("\(context) \(message)")
        #else
        logger.error("\(message)")
        #endif
    }

    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        logger.fault("\(context) \(message)")
        #else
        logger.fault("\(message)")
        #endif
    }

    // MARK: - Context Formatting

    private func formatContext(file: String, function: String, line: Int) -> String {
        let fileName = (file as NSString).lastPathComponent
        return "[\(fileName):\(line) \(function)]"
    }

    // MARK: - Category-Specific Loggers

    func cloudKit(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let categoryLogger = os.Logger(subsystem: subsystem, category: "CloudKit")
        log(to: categoryLogger, message: message, level: level, file: file, function: function, line: line)
    }

    func notifications(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let categoryLogger = os.Logger(subsystem: subsystem, category: "Notifications")
        log(to: categoryLogger, message: message, level: level, file: file, function: function, line: line)
    }

    func sync(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let categoryLogger = os.Logger(subsystem: subsystem, category: "Sync")
        log(to: categoryLogger, message: message, level: level, file: file, function: function, line: line)
    }

    private func log(to logger: os.Logger, message: String, level: LogLevel, file: String, function: String, line: Int) {
        #if DEBUG
        let context = formatContext(file: file, function: function, line: line)
        let fullMessage = "\(context) \(message)"
        #else
        let fullMessage = message
        #endif

        switch level {
        case .debug:
            logger.debug("\(fullMessage)")
        case .info:
            logger.info("\(fullMessage)")
        case .warning:
            logger.warning("\(fullMessage)")
        case .error:
            logger.error("\(fullMessage)")
        case .fault:
            logger.fault("\(fullMessage)")
        }
    }
}

// MARK: - Log Level

enum LogLevel {
    case debug
    case info
    case warning
    case error
    case fault
}
