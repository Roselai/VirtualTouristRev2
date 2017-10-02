//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Shukti Shaikh on 8/15/17.
//  Copyright © 2017 Shukti Shaikh. All rights reserved.
//


import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    // MARK: - properties
    var pin: Pin?
    var managedContext: NSManagedObjectContext!
    var focusedRegion: MKCoordinateRegion?
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    
    var insertedCache: [IndexPath]!
    var deletedCache: [IndexPath]!
    var updatedCache: [IndexPath]!
    var selectedCache = [IndexPath]()
   
    
    // MARK: - Outlets
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var newPhotos: UIBarButtonItem!
    @IBOutlet weak var noImagesLabel: UILabel!
    
    
    // MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.setRegion(focusedRegion!, animated: true)
        
        let latitude = focusedRegion!.center.latitude
        let longitude = focusedRegion!.center.longitude
        
        let locationCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = locationCoordinate
        annotation.title = "Photos from here"
        
        mapView.addAnnotation(annotation)
        
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        tabBarController?.tabBar.isHidden = true
        newPhotos.isEnabled = false
        configureButton()
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.fetchBatchSize = 18
        
        let idSort = NSSortDescriptor(key: #keyPath(Photo.photoID), ascending: true)
        fetchRequest.sortDescriptors = [idSort]
        fetchRequest.predicate = NSPredicate(format: "pin = %@", pin!)
        
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        
        fetchedResultsController.delegate = self
        
        doFetch()
        
        
        if let photos = fetchedResultsController.fetchedObjects {
            
            if photos.count == 0 {
                fetchPhotos(pin: pin!)
            } else {
                tabBarController?.tabBar.isHidden = false
                newPhotos.isEnabled = true
            }
        } else {
            fetchPhotos(pin: pin!)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = false
        
        
    }
    
    // MARK: - Photos methods
    
    func fetchPhotos(pin: Pin) {
        
        FlickrClient.sharedInstance().getPhotosForPin(pin: pin) { (photosArray, error) in

            guard error == nil else {
                print("Network request returned with error: \(error), \(error?.userInfo)")
                return
            }

            guard photosArray != nil else {
                print("Photos dictionay returned is nil")
                return
            }
            
           
            DispatchQueue.main.async {
                self.managedContext.performAndWait() {
                    if let photosArray = photosArray {
                        if photosArray.count == 0 {
                            self.noImagesLabel.isHidden = false
                            self.newPhotos.isEnabled = false
                            self.tabBarController?.tabBar.isHidden = true
                        } else {
                            self.noImagesLabel.isHidden = true
                        }
                        for photoDictionary in photosArray {
                            let photo = Photo(context: self.managedContext)
                            photo.title = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
                            photo.photoID = photoDictionary[Constants.FlickrResponseKeys.ID] as? String
                            photo.remoteURL = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String
                            photo.pin = pin
                        }
                    }
                    
                    do {
                        try self.managedContext.save()
                    } catch let error as NSError {
                        print("Could not save: \(error), \(error.userInfo)")
                    }
                    
                }
                
                
                if (self.fetchedResultsController.fetchedObjects?.count)! > 0 {
                    self.tabBarController?.tabBar.isHidden = false
                    self.newPhotos.isEnabled = true
                    
                }
                
            }
            
        }
    }
    
    func deleteAllPhotos() {
        
        newPhotos.isEnabled = false
        tabBarController?.tabBar.isHidden = true
        
        for photo in fetchedResultsController.fetchedObjects! {
            managedContext.delete(photo)
        }
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save context \(error), \(error.userInfo)")
        }
        
        fetchPhotos(pin: pin!)
        
    }
    
    func deleteSelectedPhotos() {
        
        var photosToDelete = [Photo]()
        
        for indexPath in selectedCache {
            photosToDelete.append(fetchedResultsController.object(at: indexPath))
        }
        
        for photo in photosToDelete {
            managedContext.delete(photo)
        }
        
        selectedCache.removeAll()
        
        configureButton()
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save context \(error), \(error.userInfo)")
        }
        
    }
    
    
    @IBAction func newPhotosButtonPressed(_ sender: Any) {
        if selectedCache.isEmpty {
            deleteAllPhotos()
        } else {
            deleteSelectedPhotos()
        }

    }
    
    // MARK: - Fetch Request method
    
    func doFetch() {
        do {
            try fetchedResultsController.performFetch()
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
    }
    
    
}

// MARK: - EXTENSION - CollectionView Delegate

extension PhotoAlbumViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
        
        cell.alpha = 0.5

        if let index = selectedCache.index(of: indexPath) {
            selectedCache.remove(at: index)
        } else {
            selectedCache.append(indexPath)
        }
        
        configure(cell, for: indexPath)
        
        configureButton()
    }
    
  
    
}

// MARK: - EXTENSION - Internals

extension PhotoAlbumViewController {
    
    func configure(_ cell: UICollectionViewCell, for indexPath: IndexPath) {
        
        guard let cell = cell as? PhotoCollectionViewCell else { return }
        
        var image: UIImage
        
        let photo = fetchedResultsController.object(at: indexPath)
        
        image = UIImage(named: "placeHolder")!
        
        if photo.image != nil {
            
            image = UIImage(data: photo.image! as Data)!
            cell.spinner.stopAnimating()
        } else {
            
            if let imagePath = photo.remoteURL {
                let url = URL(string: imagePath)
                _ = FlickrClient.sharedInstance().downloadimageData(photoURL: url!, completionHandlerForDownloadImageData: { (imageData, error) in
            
                    
                    // GUARD - check for error
                    guard error == nil else {
                        print("Error fetching photo data: \(error)")
                        return
                    }
                    
                    // GUARD - check for valid data
                    guard let imageData = imageData else {
                        print("No data returned for photo")
                        return
                    }
                    
                    // Dispatch on main queue to update photo image
                    DispatchQueue.main.async {
                        photo.image = imageData as NSData?
                        image = UIImage(data: photo.image as! Data)!
                        cell.update(with: image)
                        
                    }
                })
            }
        }
        
        cell.imageView.image = image
        
    }
    
    func configureButton() {
        if selectedCache.isEmpty {
            
            newPhotos.title = "Remove all photos"
        } else {
            
            newPhotos.title = "Remove selected photos"
        }
    }
    
    
}

// MARK: - EXTENSION - CollectionView Datasource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    
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
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        configure(cell, for: indexPath)
        
        return cell
    }
    
}

// MARK: - NSFetchedResultsControllerDelegate
extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    
    
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
}

// MARK: - EXTENSION - collectionView Data Source Prefetching

extension PhotoAlbumViewController: UICollectionViewDataSourcePrefetching {
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        
        for indexPath in indexPaths {
            
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
            
            configure(cell, for: indexPath)
        }
    }
}
