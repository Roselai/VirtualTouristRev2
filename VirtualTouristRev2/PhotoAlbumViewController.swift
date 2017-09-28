//
//  PhotoAlbumViewController.swift
//  VirtualTouristRev1
//
//  Created by Shukti Shaikh on 9/26/17.
//  Copyright © 2017 Shukti Shaikh. All rights reserved.
//

import UIKit
import CoreData
import MapKit

// MARK: Properties
class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate, UICollectionViewDataSourcePrefetching {
    
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    
    var focusedRegion: MKCoordinateRegion?
    var pin: Pin?
    var managedContext: NSManagedObjectContext!
    
    var insertedCache: [IndexPath]!
    var deletedCache: [IndexPath]!
    var updatedCache: [IndexPath]!
    var selectedCache = [IndexPath]()
    var imagesRetreived = false
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.setRegion(focusedRegion!, animated: true)
        
        // Drop a pin at that location
        
        let annotation = MKPointAnnotation()
        annotation.coordinate.latitude = focusedRegion!.center.latitude
        annotation.coordinate.longitude = focusedRegion!.center.longitude
        annotation.title = "Photos from here"
        
        mapView.addAnnotation(annotation)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        //Setup
        enableAttributes()
        configureButton()
        
        // set-up the fetchedResultController
        
        // 1. set the fetchRequest
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.fetchBatchSize = 18
        let idSort = NSSortDescriptor(key: #keyPath(Photo.photoID), ascending: true)
        fetchRequest.sortDescriptors = [idSort]
        fetchRequest.predicate = NSPredicate(format: "pin = %@", pin!)
        
        // 2. create the fetchedResultsController
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // 3. set the delegate
        
        fetchedResultsController.delegate = self
        
        // 4. perform the fetch
        
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        
        if let photos = fetchedResultsController.fetchedObjects {
            if photos.count == 0 {
                fetchPhotos(pin: pin!)
            } else {
                imagesRetreived = true
                enableAttributes()
            }
        } else {
            fetchPhotos(pin: pin!)
        }
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    @IBAction func getNewPhotosButton(_ sender: Any) {
        if selectedCache.isEmpty {
            // Delete all photos and get new ones
            deleteAllPhotos()
        } else {
            // Delete Selected Photos
            deleteSelectedPhotos()
        }
        
    }
    
    func deleteAllPhotos() {
        
        // First prevent the button from being pressed a second time
        newCollectionButton.isEnabled = false
        tabBarController?.tabBar.isHidden = true
        
        // Then delete all photos from the context
        for photo in fetchedResultsController.fetchedObjects! {
            managedContext.delete(photo)
        }
        
        // save the context to persist the change
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save context \(error), \(error.userInfo)")
        }
        
        // refetch new photos from network
        fetchPhotos(pin: pin!)
        
    }
    
    func deleteSelectedPhotos() {
        
        var photosToDelete = [Photo]()
        
        // get the list of Photos to delete from the indexPath array
        for indexPath in selectedCache {
            photosToDelete.append(fetchedResultsController.object(at: indexPath))
        }
        
        // remove each photo from the managed context
        for photo in photosToDelete {
            managedContext.delete(photo)
        }
        
        // reset the selection of photos
        selectedCache.removeAll()
        
        // update the interface
        configureButton()
        
        // save the context
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save context \(error), \(error.userInfo)")
        }
        
    }
    
    
    func fetchPhotos(pin: Pin) {
        
        // Send the request to the Flickr API to get photos at location
        FlickrClient.sharedInstance().getPhotosForPin(pin: pin) { (photosArray, error) in
            
            // GUARD: was there an error?
            guard error == nil else {
                print("Network request returned with error: \(error), \(error?.userInfo)")
                return
            }
            
            // Did we receive photos
            guard photosArray != nil else {
                print("Photos dictionay returned is nil")
                return
            }
            
            // Process the photos dictionary asynchronously on the main thread
            DispatchQueue.main.async {
                self.managedContext.performAndWait() {
                    if let photosArray = photosArray {
                        if photosArray.count == 0 {
                            self.enableAttributes()
                        }
                        self.imagesRetreived = true
                        self.enableAttributes()
                        
                        // process the photos in the returned dictionary
                        for photoDict in photosArray {
                            let photo = Photo(context: self.managedContext)
                            photo.title = photoDict[Constants.FlickrResponseKeys.Title] as? String
                            photo.photoID = photoDict[Constants.FlickrResponseKeys.ID] as? String
                            photo.remoteURL = photoDict[Constants.FlickrResponseKeys.ImagePath] as? String
                            photo.pin = pin
                        }
                    }
                    // when all photos objects are created, save the context
                    do {
                        try self.managedContext.save()
                    } catch let error as NSError {
                        print("Could not save: \(error), \(error.userInfo)")
                    }
                    
                }
                
                // and re-enable the button if photos were found
                if (self.fetchedResultsController.fetchedObjects?.count)! > 0 {
                    self.enableAttributes()
                    
                }
                
            }
            
        }
        
        
    }
    
    func enableAttributes() {
        if imagesRetreived {
            // self.noImagesLabel.isHidden = true
        } else {
            // self.noImagesLabel.isHidden = false
            // Disable interface for deleting or reloading photos
            self.newCollectionButton.isEnabled = false
            self.tabBarController?.tabBar.isHidden = true
            
        }
    }
    
    func configureButton() {
        if selectedCache.isEmpty {
            // No photos selected, so option is to remove all photos
            newCollectionButton.title = "Remove all photos"
        } else {
            // Some photos are selected, so option is to remove those
            newCollectionButton.title = "Remove selected photos"
        }
    }
    
    
    //MARK:
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        
        // Toggle selection of this cell
        if let index = selectedCache.index(of: indexPath) {
            selectedCache.remove(at: index)
        } else {
            selectedCache.append(indexPath)
        }
        
        
        // get a reference to the object for the cell
        let photo = fetchedResultsController.object(at: indexPath)
        
        var image: UIImage
        // check to see if the image is already in core data
        if photo.image != nil {
            image = UIImage(data: photo.image! as Data)!
            cell.update(with: image)
            
        } else {
            // image has not been downloaded, try to download it
            if let urlString = photo.remoteURL {
                
                if let imagePath = URL(string: urlString) {
                    
                    _  =  FlickrClient.sharedInstance().downloadimageData(photoURL: imagePath, completionHandlerForDownloadImageData: { (imageData, error) in
                        // GUARD - check for error
                        guard error == nil else {
                            print("Error fetching photo data: \(error)")
                            return
                        }
                        
                        // GUARD - check for valid data
                        guard let result = imageData else {
                            print("No data returned for photo")
                            return
                        }
                        
                        // Dispatch on main queue to update photo image
                        DispatchQueue.main.async {
                            var image: UIImage
                            photo.image = result as NSData?
                            image = UIImage(data: result)!
                            cell.update(with: image)
                            self.configureButton()
                        }
                        
                        
                        
                    })
                    
                }
            }
            
        }
        
    }
    
    
    
    
    
    //MARK: FetchedResultsController Delegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        insertedCache = [IndexPath]()
        deletedCache = [IndexPath]()
        updatedCache = [IndexPath]()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            
            insertedCache.append(newIndexPath!)
        case .delete:
            
            deletedCache.append(indexPath!)
        case .move:
            print("=== didChange .move type")
            deletedCache.append(indexPath!)
            insertedCache.append(newIndexPath!)
        case .update:
            updatedCache.append(indexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        
        collectionView.performBatchUpdates({
            for indexPath in self.insertedCache {
                self.collectionView.insertItems(at: [indexPath])
            }
            for indexPath in self.deletedCache {
                self.collectionView.deleteItems(at: [indexPath])
            }
            for indexPath in self.updatedCache {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }, completion: nil)
    }
    
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
        
        // get a reference to the object for the cell
        let photo = fetchedResultsController.object(at: indexPath)
        
        var image: UIImage
        // check to see if the image is already in core data
        if photo.image != nil {
            image = UIImage(data: photo.image! as Data)!
            cell.update(with: image)
            
        } else {
            // image has not been downloaded, try to download it
            if let urlString = photo.remoteURL {
                
                if let imagePath = URL(string: urlString) {
                    
                    _  =  FlickrClient.sharedInstance().downloadimageData(photoURL: imagePath, completionHandlerForDownloadImageData: { (imageData, error) in
                        // GUARD - check for error
                        guard error == nil else {
                            print("Error fetching photo data: \(error)")
                            return
                        }
                        
                        // GUARD - check for valid data
                        guard let result = imageData else {
                            print("No data returned for photo")
                            return
                        }
                        
                        // Dispatch on main queue to update photo image
                        DispatchQueue.main.async {
                            var image: UIImage
                            photo.image = result as NSData?
                            image = UIImage(data: result)!
                            cell.update(with: image)
                            self.configureButton()
                        }
                        
                        
                        
                    })
                    
                }
            }
            
        }
        
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            // Create a cell
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
            
            // get a reference to the object for the cell
            let photo = fetchedResultsController.object(at: indexPath)
            
            var image: UIImage
            // check to see if the image is already in core data
            if photo.image != nil {
                image = UIImage(data: photo.image! as Data)!
                cell.update(with: image)
                
            } else {
                // image has not been downloaded, try to download it
                if let urlString = photo.remoteURL {
                    
                    if let imagePath = URL(string: urlString) {
                        
                        _  =  FlickrClient.sharedInstance().downloadimageData(photoURL: imagePath, completionHandlerForDownloadImageData: { (imageData, error) in
                            // GUARD - check for error
                            guard error == nil else {
                                print("Error fetching photo data: \(error)")
                                return
                            }
                            
                            // GUARD - check for valid data
                            guard let result = imageData else {
                                print("No data returned for photo")
                                return
                            }
                            
                            // Dispatch on main queue to update photo image
                            DispatchQueue.main.async {
                                var image: UIImage
                                photo.image = result as NSData?
                                image = UIImage(data: result)!
                                cell.update(with: image)
                                self.configureButton()
                            }
                            
                            
                            
                        })
                        
                    }
                }
                
            }
            
        }
    }
    
    
}
