//
//  PageViewController.swift
//  MangaReader
//
//  Created by Juan on 2/20/19.
//  Copyright © 2019 Bakura. All rights reserved.
//

import UIKit

class PageViewController: UIViewController {
    @IBOutlet weak var pageImageView: UIImageView!
    
    var pageData = Data() {
        didSet {
            if self.pageImageView != nil {
                self.loadImage()
            }
        }
    }
    var page = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.loadImage()
    }
    
    func loadImage() {
        if let pageImage = UIImage(data: self.pageData) {
            self.pageImageView.image = pageImage
        }
    }
}
