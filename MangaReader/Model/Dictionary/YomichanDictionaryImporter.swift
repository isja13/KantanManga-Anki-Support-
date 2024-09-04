//
//  YomichanDictionaryImporter.swift
//  Kantan-Manga
//
//  Created by Juan on 27/11/20.
//

import Foundation
import GRDB
import ZIPFoundation

class YomichanDictionaryDecoder: DictionaryDecoder {
    static let termBankFileFormat = "term_bank_%d.json"
    static let termMetaBankFileFormat = "term_meta_bank_%d.json"
    static let kanjiBankFileFormat = "kanji_bank_%d.json"
    static let kanjiMetaBankFileFormat = "kanji_meta_bank_%d.json"
    static let tagBankFileFormat = "tag_bank_%d.json"

    weak var delegate: DictionaryDecoderDelegate?

    private var currentProgress: Float = 0
    private var numberOfFiles: Float = 1
    private var progress: ((Float) -> Void)?
    func decodeDictionary(path: URL, indexCompletion: ((DictionaryIndex) -> Void)?, progress: ((Float) -> Void)?) throws -> DecodedDictionary {
        guard let zipFile = Archive(url: path, accessMode: .read) else {
            print("Error: Cannot read the ZIP file at path \(path).")
            throw DictionaryDecoderError.canNotReadFile
        }

        print("Decoding dictionary from \(path).")
        self.currentProgress = 0
        self.progress = progress
        numberOfFiles = Float(zipFile.makeIterator().reduce(0, { $0 + ($1.type == .file ? 1 : 0) }))
        print("Total number of files to process: \(numberOfFiles).")
        
        let index = try importIndex(zip: zipFile)
        indexCompletion?(index)
        if let delegate = delegate, !delegate.shouldContinueDecoding(dictionary: index) {
            print("Decoding cancelled by delegate after processing index.")
            throw DictionaryDecoderError.decodeCancelled
        }

        let termList: [TermEntry]
        let kanjiList: [KanjiEntry]
        
        
        if index.fileVersion == .v1 {
            print("Using v1 format for decoding terms and kanjis.")
            
            termList = try readFileSequence(fileFormat: YomichanDictionaryDecoder.termBankFileFormat, zip: zipFile) as [TermEntryV1]
            kanjiList = try readFileSequence(fileFormat: YomichanDictionaryDecoder.kanjiBankFileFormat, zip: zipFile) as [KanjiEntryV1]
        } else {
            print("Using v3 format for decoding terms and kanjis.")
            termList = try readFileSequence(fileFormat: YomichanDictionaryDecoder.termBankFileFormat, zip: zipFile) as [TermEntryV3]
            kanjiList = try readFileSequence(fileFormat: YomichanDictionaryDecoder.kanjiBankFileFormat, zip: zipFile) as [KanjiEntryV3]
        }
        let termMetaList: [TermMetaEntry] = try readFileSequence(fileFormat: YomichanDictionaryDecoder.termMetaBankFileFormat, zip: zipFile)
        let kanjiMetaList: [KanjiMetaEntry] = try readFileSequence(fileFormat: YomichanDictionaryDecoder.kanjiMetaBankFileFormat, zip: zipFile)
        let tagList: [TagEntry] = try readFileSequence(fileFormat: YomichanDictionaryDecoder.tagBankFileFormat, zip: zipFile)
        
        print("Successfully decoded dictionary from \(path).")

        return DecodedDictionary(index: index, termList: termList, termMetaList: termMetaList, kanjiList: kanjiList, kanjiMetaList: kanjiMetaList, tags: tagList)
    }

    private func importIndex(zip: Archive) throws -> DictionaryIndex {
        guard let indexFile = zip["index.json"] else {
            print("Error: index.json not found in the ZIP archive.")
            throw DictionaryDecoderError.indexNotFound
        }

        var data = Data()
        _ = try zip.extract(indexFile) { partData in
            data.append(partData)
        }

        print("Successfully extracted index.json.")
        let decoder = JSONDecoder()
        let index = try decoder.decode(DictionaryIndex.self, from: data)
        updateProgress()
        print("Successfully decoded the dictionary index.")
        return index
    }

    private func readFileSequence<T: Decodable>(fileFormat: String, zip: Archive) throws -> [T] {
        var results = [T]()
        let decoder = JSONDecoder()
        var index = 1
        
        while let file = zip[String(format: fileFormat, index)] {
            print("Processing file: \(file.path).")
            var data = Data()
            _ = try zip.extract(file) { partData in
                data.append(partData)
            }
            let entries = try decoder.decode([T].self, from: data)
            results.append(contentsOf: entries)
            index += 1
            updateProgress()
            print("Successfully decoded file: \(file.path).")
        }
        return results
    }

    private func updateProgress() {
        let step = 1 / numberOfFiles
        currentProgress += step
        progress?(currentProgress)
        print("Updated progress: \(currentProgress * 100)%.")
    }
}
