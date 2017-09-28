//
//  PhotoDataSource.swift
//  VirtualTouristRev2
//
//  Created by Shukti Shaikh on 9/27/17.
//  Copyright © 2017 Shukti Shaikh. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PhotoDataSource: NSObject, UICollectionViewDataSource {
    
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    
    
    //MARK: CollectionView Data Source
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        guard let sections = fetchedResultsController.sections else { return 1 }
        
        return sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard let sectionInfo = fetchedResultsController.sections?[section] else {
            return 0
        }
        
        return sectionInfo.numberOfObjects
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Create a cell
        let identifier = "PhotoCollectionViewCell"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! PhotoCollectionViewCell
        
        
        return cell
    }
    
    
    
    
}
