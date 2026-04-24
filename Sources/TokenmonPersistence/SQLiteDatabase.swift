import Foundation
import SQLite3

public enum SQLiteValue {
    case integer(Int64)
    case double(Double)
    case text(String)
    case null
}

public final class SQLiteDatabase {
    private let handle: OpaquePointer
    private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)

        guard result == SQLITE_OK, let db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
            if let db {
                sqlite3_close(db)
            }
            throw SQLiteError.openFailed(message)
        }

        handle = db
        sqlite3_busy_timeout(handle, 5_000)
        try execute("PRAGMA busy_timeout = 5000;")
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        sqlite3_close(handle)
    }

    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        let statement = try prepare(sql: sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw SQLiteError.statementFailed(message: errorMessage, sql: sql)
        }
    }

    public func fetchAll<T>(_ sql: String, bindings: [SQLiteValue] = [], map: (OpaquePointer) throws -> T) throws -> [T] {
        let statement = try prepare(sql: sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        var rows: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                rows.append(try map(statement))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.statementFailed(message: errorMessage, sql: sql)
            }
        }

        return rows
    }

    public func fetchOne<T>(_ sql: String, bindings: [SQLiteValue] = [], map: (OpaquePointer) throws -> T) throws -> T? {
        let statement = try prepare(sql: sql)
        defer { sqlite3_finalize(statement) }

        try bind(bindings, to: statement)

        let result = sqlite3_step(statement)
        if result == SQLITE_ROW {
            return try map(statement)
        }
        if result == SQLITE_DONE {
            return nil
        }

        throw SQLiteError.statementFailed(message: errorMessage, sql: sql)
    }

    public func changes() -> Int {
        Int(sqlite3_changes(handle))
    }

    public func lastInsertRowID() -> Int64 {
        sqlite3_last_insert_rowid(handle)
    }

    public func inTransaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public func inReadTransaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN DEFERRED TRANSACTION;")
        do {
            let value = try body()
            try execute("COMMIT;")
            return value
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    public static func columnInt64(_ statement: OpaquePointer, index: Int32) -> Int64 {
        sqlite3_column_int64(statement, index)
    }

    public static func columnDouble(_ statement: OpaquePointer, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    public static func columnText(_ statement: OpaquePointer, index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: text)
    }

    public static func columnOptionalText(_ statement: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return columnText(statement, index: index)
    }

    public static func columnOptionalInt64(_ statement: OpaquePointer, index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return columnInt64(statement, index: index)
    }

    public static func columnOptionalDouble(_ statement: OpaquePointer, index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return columnDouble(statement, index: index)
    }

    private func prepare(sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw SQLiteError.statementFailed(message: errorMessage, sql: sql)
        }
        return statement
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer) throws {
        for (index, value) in values.enumerated() {
            let parameterIndex = Int32(index + 1)
            let result: Int32

            switch value {
            case .integer(let integer):
                result = sqlite3_bind_int64(statement, parameterIndex, integer)
            case .double(let double):
                result = sqlite3_bind_double(statement, parameterIndex, double)
            case .text(let text):
                result = sqlite3_bind_text(statement, parameterIndex, text, -1, transientDestructor)
            case .null:
                result = sqlite3_bind_null(statement, parameterIndex)
            }

            guard result == SQLITE_OK else {
                throw SQLiteError.bindFailed(message: errorMessage)
            }
        }
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(handle))
    }
}

public enum SQLiteError: Error, LocalizedError {
    case openFailed(String)
    case statementFailed(message: String, sql: String)
    case bindFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            return "sqlite open failed: \(message)"
        case .statementFailed(let message, let sql):
            return "sqlite statement failed: \(message) | sql=\(sql)"
        case .bindFailed(let message):
            return "sqlite bind failed: \(message)"
        }
    }
}
