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
        
        // set up portion of the map with the selected pin
        mapView.setRegion(focusedRegion!, animated: true)
        
        // Drop a pin at that location
        
        let latitude = focusedRegion!.center.latitude
        let longitude = focusedRegion!.center.longitude
        
        let locationCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = locationCoordinate
        annotation.title = "Photos from here"
        
        mapView.addAnnotation(annotation)
        
        // set delegates for the collectionView
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // new to iOS 10 - enable prefetcing
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        // Disable bottom button until photos are displayed
        tabBarController?.tabBar.isHidden = true
        newPhotos.isEnabled = false
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
        
        doFetch()
        
        
        if let photos = fetchedResultsController.fetchedObjects {
            
            if photos.count == 0 {
                // no photos at this location, fetch new ones
                fetchPhotos(pin: pin!)
            } else {
                // there are photos in this location so display them (nothing to do for that, except...)
                // we need to enable the bottom button
                tabBarController?.tabBar.isHidden = false
                newPhotos.isEnabled = true
            }
        } else {
            // photos is nil so there are no photos: fetch photos
            fetchPhotos(pin: pin!)
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = false
        
        
    }
    
    // MARK: - Photos methods
    
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
                            // NO photos in returned data
                            // Display label to indicate no photos to user
                            self.noImagesLabel.isHidden = false
                            // Disable interface for deleting or reloading photos
                            self.newPhotos.isEnabled = false
                            self.tabBarController?.tabBar.isHidden = true
                        } else {
                            // We have images so hide the "no photos" label
                            self.noImagesLabel.isHidden = true
                        }
                        // process the photos in the returned dictionary
                        for photoDictionary in photosArray {
                            // Here we save the photos' URL, ID and title but not the actual photos,
                            // that is done in the cellForItemAtIndexpath method
                            // as each photo is required (and if needed)
                            let photo = Photo(context: self.managedContext)
                            photo.title = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
                            photo.photoID = photoDictionary[Constants.FlickrResponseKeys.ID] as? String
                            photo.remoteURL = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String
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
                    self.tabBarController?.tabBar.isHidden = false
                    self.newPhotos.isEnabled = true
                    
                }
                
            }
            
        }
    }
    
    func deleteAllPhotos() {
        
        // First prevent the button from being pressed a second time
        newPhotos.isEnabled = false
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
    
    
    @IBAction func newPhotosButtonPressed(_ sender: Any) {
        if selectedCache.isEmpty {
            // Button is to delete all photos and load new ones
            deleteAllPhotos()
        } else {
            // Button is to delete selected photos
            deleteSelectedPhotos()
        }

    }
    
    // MARK: - Fetch Request method
    
    // execute the fetch request
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
        
        
        // Toggle selection of this cell
        if let index = selectedCache.index(of: indexPath) {
            selectedCache.remove(at: index)
        } else {
            selectedCache.append(indexPath)
        }
        
        // reconfigure the cell
        configure(cell, for: indexPath)
        
        // update interface
        configureButton()
    }
    
  
    
}

// MARK: - EXTENSION - Internals

extension PhotoAlbumViewController {
    
    // Configure the collectionView cell
    func configure(_ cell: UICollectionViewCell, for indexPath: IndexPath) {
        
        guard let cell = cell as? PhotoCollectionViewCell else { return }
        
        var image: UIImage
        
        
        // get a reference to the object for the cell
        let photo = fetchedResultsController.object(at: indexPath)
        // default value for image
        image = UIImage(named: "placeHolder")!
        // check to see if the image is already in core data
        if photo.image != nil {
            // image exists, use it
            image = UIImage(data: photo.image! as Data)!
            cell.spinner.stopAnimating()
        } else {
            // image has not been downloaded, try to download it
            if let imagePath = photo.remoteURL {
                let url = URL(string: imagePath)
                FlickrClient.sharedInstance().downloadimageData(photoURL: url!, completionHandlerForDownloadImageData: { (imageData, error) in
            
                    
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
            // No photos selected, so option is to remove all photos
            newPhotos.title = "Remove all photos"
        } else {
            // Some photos are selected, so option is to remove those
            newPhotos.title = "Remove selected photos"
        }
    }
    
    
}

// MARK: - EXTENSION - CollectionView Datasource

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
    // MARK: - CollectionView Datasource methods
    
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
            // Create a cell
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
            
            configure(cell, for: indexPath)
        }
    }
}
