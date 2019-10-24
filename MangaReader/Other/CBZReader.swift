//
//  CBZReader.swift
//  MangaReader
//
//  Created by Juan on 2/20/19.
//  Copyright © 2019 Bakura. All rights reserved.
//

import ZIPFoundation

enum CBZReaderError: Error {
    case invalidFilePath
    case errorCreatingArhive
}

class CBZReader {
    private var fileName = ""
    private var archive: Archive
    private var fileEntries = [Entry]()
    private var observers = [NSKeyValueObservation]()
    private var progresses = [Progress]()
    private var cache = [Int: Data]()
    public var numberOfPages = 0

    init(fileName: String) throws {
        self.fileName = fileName
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsDirectory.appendingPathComponent(fileName)
        guard let archive = Archive(url: filePath, accessMode: .read) else {
            throw CBZReaderError.errorCreatingArhive
        }
        self.archive = archive
        for entry in self.archive.makeIterator() where entry.type == .file {
            self.fileEntries.append(entry)
        }
        self.numberOfPages = fileEntries.count
    }

    func readFirstEntry(_ callBack: @escaping (_: Data?) -> Void) {
        self.readEntityAt(index: 0, callBack)
    }

    func readEntityAt(index: Int, _ callBack: @escaping (_: Data?) -> Void) {
        guard index >= 0 && index < self.fileEntries.count else {
            callBack(nil)
            return
        }

        if let entry = self.cache[index] {
            callBack(entry)
            return
        }

        var tempData = Data()
        let progress = Progress()
        self.progresses.append(progress)
        self.observers.append(progress.observe(\.fractionCompleted, changeHandler: { (progress, _) in
            if progress.fractionCompleted == 1 {
                callBack(tempData)
                self.cache[index] = tempData
                self.progresses = self.progresses.filter {$0 != progress}
                _ = self.observers.popLast()
            }
        }))
        let entry = self.fileEntries[index]
        do {
            _ = try archive.extract(entry, bufferSize: UInt32(16*1024), progress: progress, consumer: { (aData) in
                tempData.append(aData)
            })
        } catch {
            callBack(nil)
        }
    }
}
