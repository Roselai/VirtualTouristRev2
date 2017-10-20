//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Shukti Shaikh on 8/15/17.
//  Copyright © 2017 Shukti Shaikh. All rights reserved.
//

import Foundation
import MapKit
import CoreData



class MapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    //let delegate = UIApplication.shared.delegate as! AppDelegate
    let persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { (description, error) in
            if let error = error {
                print("Error setting up Core Data (\(error)).")
            }
        }
        return container
    }()
    
    var managedContext: NSManagedObjectContext!
    
    let defaults = UserDefaults.standard
    var asyncFetchRequest: NSAsynchronousFetchRequest<Pin>!
    
    var pin: Pin?
    var pins: [Pin] = []
    var restoringRegion = false
    var longPressRecognizer: UILongPressGestureRecognizer!
    var region: MKCoordinateRegion?
    var dragPin: MKPointAnnotation!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true
        
        mapView.delegate = self
        
        managedContext = persistentContainer.viewContext
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.addPin(gestureRecognizer:)))
        longPressRecognizer.numberOfTouchesRequired = 1
        mapView.addGestureRecognizer(longPressRecognizer)
        
        
        if restoringRegion == false {
            mapView.setRegion(mapView.regionThatFits(mapView.region), animated: true)
        }
        restoreMapRegion(animated: true)
        
        
        
        fetchAllPins { (result) in
            if result == nil {
                print("no pins to display")
            } else {
                for pin in result! {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate.latitude = pin.latitude
                    annotation.coordinate.longitude = pin.longitude
                    
                    self.mapView.addAnnotation(annotation)
                }
            }
        }
        
        
        print(Constants.FlickrParameterValues.Page)
        
    }
    
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = true
        saveContext(context: managedContext)
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        self.navigationController?.isNavigationBarHidden = false
        saveMapRegion()
    }
    
    
    
    func addPin(gestureRecognizer: UIGestureRecognizer){
        let touchPoint = gestureRecognizer.location(in: mapView)
        let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        if dragPin != nil {
            dragPin.coordinate = newCoordinates
        }
        
        if gestureRecognizer.state == UIGestureRecognizerState.began {
            dragPin = MKPointAnnotation()
            dragPin.coordinate = newCoordinates
            mapView.addAnnotation(dragPin)
            
            
        } else if gestureRecognizer.state == UIGestureRecognizerState.ended {
            dragPin = nil
            
            persistentContainer.performBackgroundTask() { (context) in
            let pin = Pin(context: context)
            pin.latitude = newCoordinates.latitude
            pin.longitude = newCoordinates.longitude
            
                self.saveContext(context: context)
            }
            
        }
    }
    
    
    
    
    func fetchAllPins(completion: @escaping ([Pin]?) -> Void) {
        
        do {
            let pinFetch: NSFetchRequest<Pin> = Pin.fetchRequest()
            let pins = try managedContext.fetch(pinFetch)
            if pins.isEmpty {
                completion(nil)
                return
            }
            completion(pins)
            
            
        } catch let error as NSError {
            print("Fetch error: \(error), \(error.userInfo)")
        }
        
        
    }
    
    
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let identifier = "annotationView"
        
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
        
        if annotationView != nil {
            annotationView!.annotation = annotation
        } else {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = false
            annotationView!.animatesDrop = true
        }
        return annotationView
    }
    
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        mapView.deselectAnnotation(view.annotation! , animated: true)
        
        guard view.annotation != nil else { return }
        
        let coordinate = view.annotation?.coordinate
        let precision = 0.0001
        let firstPredicate = NSPredicate(format: "(\(#keyPath(Pin.latitude)) BETWEEN {\((coordinate?.latitude)! - precision), \((coordinate?.latitude)! + precision) })")
        let secondPredicate = NSPredicate(format: "(\(#keyPath(Pin.longitude)) BETWEEN {\((coordinate?.longitude)! - precision), \((coordinate?.longitude)! + precision) })")
        let predicate = NSCompoundPredicate(type: .and , subpredicates: [firstPredicate, secondPredicate])
        
        
        let pinFetch: NSFetchRequest<Pin> = Pin.fetchRequest()
        pinFetch.predicate = predicate
        
        
        do {
            let pins = try managedContext.fetch(pinFetch)
            
            if pins.count > 0 {
                if pins.count > 1 {
                    self.pin = pins.first
                    print("More than one pin returned from fetc: \(pins.count)")
                    
                    
                    self.presentPhotoAlbumViewController(pin: pin!, coordinate: coordinate!)
                    
                    
                } else {
                    self.pin = pins.first
                    self.presentPhotoAlbumViewController(pin: pin!, coordinate: coordinate!)
                    
                }
            } else {
                print("Could not find a matching pin for this latitude: \(coordinate!.latitude) and longitude: \(coordinate!.longitude)")
            }
            
        } catch let error as NSError {
            print("Fetch error: \(error), \(error.userInfo)")
        }
        
        
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if restoringRegion == false {
            saveMapRegion()
        }
    }
    
    
    
    func presentPhotoAlbumViewController(pin: Pin, coordinate: CLLocationCoordinate2D) {
        
        let center = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let longitudeDelta = mapView.region.span.longitudeDelta
        let latitudeDelta = mapView.region.span.latitudeDelta / 3
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        region = MKCoordinateRegion(center: center, span: span)
        
        performSegue(withIdentifier: "showPhotos", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showPhotos" {
            
            if let destinationViewController = segue.destination as? PhotoAlbumViewController {
                destinationViewController.pin = pin
                destinationViewController.focusedRegion = region
                destinationViewController.managedContext = managedContext
                destinationViewController.persistentContainer = persistentContainer
                
            }
        }
        
    }
    
    
    
    func saveMapRegion() {
        defaults.set(mapView.region.center.latitude, forKey: "latitude")
        defaults.set(mapView.region.center.longitude, forKey: "longitude")
        defaults.set(mapView.region.span.latitudeDelta, forKey: "latitudeDelta")
        defaults.set(mapView.region.span.longitudeDelta, forKey: "longitudeDelta")
    }
    
    
    
    func restoreMapRegion(animated: Bool) {
        
        restoringRegion = true
        
        let latitude = defaults.double(forKey: "latitude")
        let longitude = defaults.double(forKey: "longitude")
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let longitudeDelta = defaults.double(forKey: "latitudeDelta")
        let latitudeDelta = defaults.double(forKey: "longitudeDelta")
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        
        let savedRegion = MKCoordinateRegion(center: center, span: span)
        
        mapView.setRegion(savedRegion, animated: animated)
        restoringRegion = false
    }
    
    
    
    
    
    func saveContext (context: NSManagedObjectContext){
        do {
            try context.save()
        } catch let error as NSError {
            print("Could not save context \(error), \(error.userInfo)")
        }
    }
    
    
    
    
    
    
}

