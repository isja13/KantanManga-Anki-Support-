//
//  ViewMangaCoordinator.swift
//  MangaReader
//
//  Created by Juan on 26/11/19.
//  Copyright © 2019 Bakura. All rights reserved.
//

import Foundation
import Firebase

protocol ViewMangaCoordinatorDelegate: AnyObject {
    func didEnd(_ viewMangaCoordinator: ViewMangaCoordinator)
}

class ViewMangaCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()

    private let navigation: Navigable
    private let coreDataManager: CoreDataManageable
    private weak var delegate: ViewMangaCoordinatorDelegate?
    private let manga: Manga
    private let originFrame: CGRect

    private var mangaDataSource: MangaDataSourceable!
    private var mangaViewController: MangaViewController?
    private var ocr: ImageOCR

    init(navigation: Navigable, coreDataManager: CoreDataManageable, manga: Manga, delegate: ViewMangaCoordinatorDelegate, originFrame: CGRect, ocr: ImageOCR) {
        self.navigation = navigation
        self.coreDataManager = coreDataManager
        self.manga = manga
        self.delegate = delegate
        self.originFrame = originFrame
        self.ocr = ocr
        super.init()
        mangaDataSource = createMangaDataSource(manga: manga, readerBuilder: { (path, completion) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let reader = try GenericReader(fileName: path)
                    completion(reader)
                } catch let error {
                    print("Error creating reader: \(error.localizedDescription)")
                }
            }
        })
    }

    func start() {
        guard mangaDataSource != nil else {
            delegate?.didEnd(self)
            return
        }
        let mangaViewController = MangaViewController(manga: manga, dataSource: mangaDataSource, delegate: self, firstTime: !UserDefaults.standard.bool(forKey: "hasSeenManga"))
        UserDefaults.standard.setValue(true, forKey: "hasSeenManga")
        navigation.delegate = self
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.pushViewController(mangaViewController, animated: true)
        self.mangaViewController = mangaViewController
    }

    func createMangaDataSource(manga: Manga, readerBuilder: (String, @escaping (Reader) -> Void) -> Void) -> MangaDataSourceable? {
        MangaDataSource(manga: manga, readerBuilder: readerBuilder)
    }
}

// MARK: MangaViewControllerDelegate
extension ViewMangaCoordinator: MangaViewControllerDelegate {
    func didTapPage(_ mangaViewController: MangaViewController, pageViewController: PageViewController) {
        mangaViewController.toggleFullscreen()
    }

    func back(_ mangaViewController: MangaViewController) {
        navigation.popViewController(animated: true)
        delegate?.didEnd(self)
    }

    func didSelectSectionOfImage(_ mangaViewController: MangaViewController, image: UIImage) {
        mangaViewController.setSentence(sentence: "")
        mangaViewController.ocrStartLoading()
        ocr.recognize(image: image) { (result) in
            DispatchQueue.main.async {
                mangaViewController.ocrEndLoading()
            }
            switch result {
            case let .success(text):
                DispatchQueue.main.async {
                    mangaViewController.setSentence(sentence: text)
                }
            case let .failure(error):
                print(error.localizedDescription)
            }
        }
    }

    func didTapSettings(_ mangaViewController: MangaViewController) {
        let settings = [
            SettingsSection(title: "Pages", footer: "Use this to view double page spreads", settings: [
                ViewerPagesSettings.offsetByOne(mangaDataSource.pagesOffset)
            ]),
            SettingsSection(footer: "By default landscape is double paged and portrait single paged", settings: [
                ViewerPagesSettings.doublePaged(mangaDataSource.forceToggleMode)
            ]),
            SettingsSection(title: "Page Numbers", settings: [
                ViewerPageNumberSettings.hidePageNumbers(mangaDataSource.hidePageLabel),
                ViewerPageNumberSettings.offsetPageNumbesr(mangaDataSource.pageTextOffset)
            ])
        ]
        let settingsNavigationController = UINavigationController(rootViewController: ViewerSettingsViewController(settings: settings, delegate: self))
        navigation.present(settingsNavigationController, animated: true, completion: nil)
    }

    func pageDidChange(_ mangaViewController: MangaViewController, manga: Manga, newPage: Int) {
        manga.currentPage = Int16(newPage)
        coreDataManager.updateManga(manga: manga)
    }

    func didTapCreateSentence(_ mangaViewController: MangaViewController, image: UIImage, sentence: String, dictionaryResult: SearchTermResult) {
        let createSentenceCoordinator = EditSentenceCoordinator(
            navigation: navigation,
            image: image,
            word: dictionaryResult.term.expression,
            reading: dictionaryResult.term.reading,
            sentence: sentence,
            definition: dictionaryResult.term.formattedDefinition,
            delegate: self
        )
        childCoordinators.append(createSentenceCoordinator)
        createSentenceCoordinator.start()
    }
}

extension ViewMangaCoordinator: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if fromVC is CollectionViewController {
            let image = manga.coverImage ?? UIImage()
            return OpenMangaAnimationController(originFrame: originFrame, mangaCover: image)
        }
        return nil
    }
}

extension ViewMangaCoordinator: ViewerSettingsViewControllerDelegate {
    func updatePagesSetting(_ viewerSettingsViewController: ViewerSettingsViewController, setting: ViewerPagesSettings, newValue: SettingValue) {
        switch setting {
        case .doublePaged:
            guard case .bool(let value) = newValue else { return }
            mangaDataSource.forceToggleMode = value
            mangaViewController?.reloadPageController()
        case .offsetByOne:
            guard case .bool(let value) = newValue else { return }
            mangaDataSource.pagesOffset = value
            mangaViewController?.reloadPageController()
        }
    }

    func updatePageNumbersSetting(_ viewerSettingsViewController: ViewerSettingsViewController, setting: ViewerPageNumberSettings, newValue: SettingValue) {
        switch setting {
        case .offsetPageNumbesr:
            guard case .number(let value) = newValue else { return }
            mangaDataSource.pageTextOffset = value
            mangaViewController?.reloadPageController()
        case .hidePageNumbers:
            guard case .bool(let value) = newValue else { return }
            mangaDataSource.hidePageLabel = value
            mangaViewController?.reloadPageController()
        }
    }

    func didSelectDone(_ viewerSettingsViewController: ViewerSettingsViewController) {
        navigation.dismiss(animated: true, completion: nil)
    }
}

extension ViewMangaCoordinator: EditSentenceCoordinatorDelegate {
    func didCancel(_ createSentenceCoordinator: EditSentenceCoordinator) {
        removeChildCoordinator(type: EditSentenceCoordinator.self)
    }

    func didEnd(_ createSentenceCoordinator: EditSentenceCoordinator, image: UIImage?, word: String, reading: String, sentence: String, definition: String) {
        coreDataManager.insertSentence(word: word, reading: reading, sentence: sentence, definition: definition, image: image)
        removeChildCoordinator(type: EditSentenceCoordinator.self)
    }
}
