//
//  CompoundDictionary.swift
//  MangaReader
//
//  Created by Juan on 10/01/20.
//  Copyright © 2020 Bakura. All rights reserved.
//

import Foundation
import GRDB

struct DictionaryResult {
    let term: String
    let reading: String
    var meanings: [GlossaryItem]
}

enum DictionaryError: Error {
    case canNotGetLibraryURL
    case dictionaryAlreadyExists
    case noConnection
    case dbFileNotFound
    case dictionaryIndexNotInserted
}

class CompoundDictionary {
    var isConnected: Bool {
        return db != nil
    }

    private var db: DatabaseQueue?

    init(db: DatabaseQueue? = nil) {
        self.db = db
    }

    private func connectTo(url: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.label = "Dictionaries"
        configuration.foreignKeysEnabled = true
        print("Attempting to connect to database at path: \(url.path)")
        let db = try DatabaseQueue(path: url.path, configuration: configuration)
        print("Successfully connected to database at path: \(url.path)")
        return db
    }
   
    func connectToDataBase(fileName: String = "dic.db", fileManager: FileManager = .default) throws {
        print("Starting database connection process...")

        // Directly access the file in the app's resources
        guard let dbPath = Bundle.main.path(forResource: "dic", ofType: "db") else {
            print("Database file not found in resources")
            throw DictionaryError.dbFileNotFound
        }

        print("Attempting to connect to database at path: \(dbPath)")

        do {
            db = try connectTo(url: URL(fileURLWithPath: dbPath))
            print("Successfully connected to database at path: \(dbPath)")
        } catch {
            print("Failed to connect to database with error: \(error)")
            throw error
        }
    }


    func createDataBase(fileName: String = "dic.db", fileManager: FileManager = .default) throws {
        print("Starting database creation process...")

        // Directly define the path for the database in the library directory
        guard let libraryUrl = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw DictionaryError.canNotGetLibraryURL
        }
        let dbUrl = libraryUrl.appendingPathComponent(fileName)
        
        print("Checking if database already exists at path: \(dbUrl.path)")
        guard !fileManager.fileExists(atPath: dbUrl.path) else {
            print("Database already exists at path: \(dbUrl.path)")
            throw DictionaryError.dictionaryAlreadyExists
        }

        do {
             let db = try connectTo(url: dbUrl)
             let migrator = DBMigrator()
             try migrator.migrate(db: db)
             self.db = db
             print("Database created and migrated successfully at path: \(dbUrl.path)")
         } catch {
             print("Failed to create and migrate database with error: \(error)")
             throw error
         }
    }


    func removeDataBase(fileName: String = "dic.db", fileManager: FileManager = .default) throws {
        guard let libraryUrl = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw DictionaryError.canNotGetLibraryURL
        }

        let dbUrl = libraryUrl.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: dbUrl.path) else {
            throw DictionaryError.dbFileNotFound
        }

        try fileManager.removeItem(at: dbUrl)
    }

    func dictionaryExists(title: String, revision: String) throws -> Bool {
        guard let db = db else {
            throw DictionaryError.noConnection
        }
        do {
            let count = try db.read { db in
                try Dictionary
                    .filter(Dictionary.Columns.title == title &&
                                Dictionary.Columns.revision == revision)
                    .fetchCount(db)
            }
            return count != 0
        } catch {
            return false
        }
    }

    func getDictionaries() throws -> [Dictionary] {
        guard let db = db else {
            throw DictionaryError.noConnection
        }

        return try db.read { db in
            try Dictionary.fetchAll(db)
        }
    }

    func addDictionary(_ decodedDictionary: DecodedDictionary, progress: ((Float) -> Void)? = nil) throws {
        guard let db = db else {
            print("Database connection is not established.")
            throw DictionaryError.noConnection
        }
        print("Starting addDictionary process for \(decodedDictionary.index.title)")
        let total = Float(decodedDictionary.totalEntries)
        var currentProgress = 0

        var dictionary = Dictionary(from: decodedDictionary.index)
        try db.write { db in
            try dictionary.insert(db)
            currentProgress += 1
            progress?(Float(currentProgress)/total)
            print("Inserted dictionary index with title \(decodedDictionary.index.title)")
        }

        guard let dictionaryId = dictionary.id else {
            print("Failed to insert dictionary index.")
            throw DictionaryError.dictionaryIndexNotInserted
        }

        // TODO: Save dictionary media
        try db.write { db in
            let terms = decodedDictionary
                .termList
                .map { Term(from: $0, dictionaryId: dictionaryId) }
            for var term in terms {
                try term.insert(db)
                currentProgress += 1
                if currentProgress % 10000 == 0 {
                    print("Inserted term batch. Current progress: \(currentProgress) / \(total)")
                    progress?(Float(currentProgress)/total)
                }
            }
            print("Inserted \(terms.count) terms into the database")
        }

        try db.write { db in
            let termsMeta = decodedDictionary
                .termMetaList
                .map { TermMeta(from: $0, dictionaryId: dictionaryId) }
            for var termMeta in termsMeta {
                try termMeta.insert(db)
                currentProgress += 1
                if currentProgress % 10000 == 0 {
                    print("Inserted termsMeta batch. Current progress: \(currentProgress) / \(total)")
                    progress?(Float(currentProgress)/total)
                }
            }
            print("Inserted \(termsMeta.count) term metadata entries into the database")
        }

        try db.write { db in
            let kanjis = decodedDictionary
                .kanjiList
                .map { Kanji(from: $0, dictionaryId: dictionaryId) }
            for var kanji in kanjis {
                try kanji.insert(db)
                currentProgress += 1
                if currentProgress % 10000 == 0 {
                    progress?(Float(currentProgress)/total)
                }
            }
            print("Inserted \(kanjis.count) kanji entries into the database")
        }

        try db.write { db in
            let kanjisMeta = decodedDictionary
                .kanjiMetaList
                .map { KanjiMeta(from: $0, dictionaryId: dictionaryId) }
            for var kanjiMeta in kanjisMeta {
                try kanjiMeta.insert(db)
                currentProgress += 1
                if currentProgress % 10000 == 0 {
                    progress?(Float(currentProgress)/total)
                }
            }
            print("Inserted \(kanjisMeta.count) kanji metadata entries into the database")
        }

        try db.write { db in
            let tags = decodedDictionary
                .tags
                .map { Tag(from: $0, dictionaryId: dictionaryId) }
            for var tag in tags {
                try tag.insert(db)
                currentProgress += 1
                if currentProgress % 10000 == 0 {
                    progress?(Float(currentProgress)/total)
                }
            }
            print("Inserted \(tags.count) tags into the database")
        }
        progress?(Float(currentProgress)/total)
        print("Finished addDictionary process for \(decodedDictionary.index.title)")
    }

    func deleteDictionary(id: Int) throws {
        guard let db = db else {
            throw DictionaryError.noConnection
        }

        _ = try db.write { db in
            try Dictionary.deleteOne(db, key: id)
        }
    }

    func findTerm(_ term: String) throws -> [MergedTermSearchResult] {
        guard let db = db else {
            throw DictionaryError.noConnection
        }

        let results: [SearchTermResult] = try db.read { db in
            let request = Term.including(required: Term.dictionary)
                .filter(
                    Term.Columns.expression == term ||
                    Term.Columns.reading == term
                )
            return try SearchTermResult.fetchAll(db, request)
        }

        let termMeta: [TermMetaSearchResult] = try db.read { db in
            let request = TermMeta.including(required: TermMeta.dictionary)
                .filter(
                    results.map { $0.term.expression }
                        .contains(TermMeta.Columns.character)
                )
            return try TermMetaSearchResult.fetchAll(db, request)
        }

        return mergeResults(results: results, termMeta: termMeta)
    }

    private func mergeResults(results: [SearchTermResult], termMeta: [TermMetaSearchResult]) -> [MergedTermSearchResult] {
        let termMeta = termMeta.keyedBy(\.termMeta.character)
        var grouped = [String: MergedTermSearchResult]()
        for result in results {
            if grouped[result.term.expression + result.term.reading] != nil {
                grouped[result.term.expression + result.term.reading]?.terms.append(result)
            } else {
                grouped[result.term.expression + result.term.reading] = MergedTermSearchResult(expression: result.term.expression,
                                                                                     reading: result.term.reading,
                                                                                     terms: [result],
                                                                                     meta: [termMeta[result.term.expression]].compactMap { $0 })
            }
        }

        return Array(grouped.values)
    }

    func findKanji(_ word: String) throws -> [FullKanjiResult] {
        let kanji = JapaneseUtils.splitKanji(word: word)

        guard let db = db else {
            throw DictionaryError.noConnection
        }

        let kanjiMeta = try db.read { db -> [KanjiMetaSearchResult] in
            let request = KanjiMeta.including(required: KanjiMeta.dictionary)
                .filter(
                    kanji.contains(KanjiMeta.Columns.character)
                )
            return try KanjiMetaSearchResult.fetchAll(db, request)
        }.keyedBy(\.kanjiMeta.character)

        let results = try db.read { db -> [KanjiSearchResult] in
            let request = Kanji.including(required: Kanji.dictionary)
                .filter(
                    kanji.contains(Kanji.Columns.character)
                )
            return try KanjiSearchResult.fetchAll(db, request)
        }.map { FullKanjiResult(kanjiResult: $0, metaResult: kanjiMeta[$0.kanji.character]) }

        return results
    }
}
