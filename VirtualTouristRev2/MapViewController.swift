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



class MapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    
    var managedContext: NSManagedObjectContext!
    
    let defaults = UserDefaults.standard
    //let pinFetch: NSFetchRequest<Pin> = Pin.fetchRequest()
    var asyncFetchRequest: NSAsynchronousFetchRequest<Pin>!
    
    var pin: Pin?
    var pins: [Pin] = []
    var restoringRegion = false
    var longPressRecognizer: UILongPressGestureRecognizer!
    var region: MKCoordinateRegion?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get the stack
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let stack = delegate.stack
        managedContext = stack.context
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self,
                                                           action: #selector(longPress(_:)))
        mapView.addGestureRecognizer(longPressRecognizer)
        
        mapView.delegate = self
        
        restoreMapRegion(animated: true)
        
        
            fetchAllPins { (result) in
                // display the pins on the map
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
 
        
        
    }
    
        
    
    



override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    do {
        try managedContext.save()
    } catch let error as NSError {
        print("Could not save context \(error), \(error.userInfo)")
    }
    
}


override func viewWillDisappear(_ animated: Bool) {
    saveMapRegion()
}




func longPress(_ sender: AnyObject) {
    
    print("Recognized a long press")
    if longPressRecognizer.state == .began {
        // Get location of the longpress in mapView
        let touchPoint = sender.location(in: mapView)
        
        // Get the map coordinate from the point pressed on the map
        let touchCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        // create annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = touchCoordinates
        mapView.addAnnotation(annotation)
        
        
        
        // now create the pin
        let pin = Pin(context: managedContext)
        pin.latitude = touchCoordinates.latitude
        pin.longitude = touchCoordinates.longitude
        
        // save the context
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Unresolved error: \(error), \(error.userInfo)")
        }
        
        
    }
    
}

func fetchAllPins(completion: @escaping ([Pin]?) -> Void) {
    
    do {
        // execute the fetch request
        let pinFetch: NSFetchRequest<Pin> = Pin.fetchRequest()
        let pins = try managedContext.fetch(pinFetch)
        // validate that there are pins in Core Data
        if pins.isEmpty {
            // no pins in Core Data, display onboarding experience
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
    let pinFetch: NSFetchRequest<Pin> = Pin.fetchRequest()
    pinFetch.predicate = NSPredicate(format: "(%K BETWEEN {\((coordinate?.latitude)! - precision), \((coordinate?.latitude)! + precision) }) AND (%K BETWEEN {\((coordinate?.longitude)! - precision), \((coordinate?.longitude)! + precision) })", #keyPath(Pin.latitude), #keyPath(Pin.longitude))
    
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
            print("Could not find a matching pin for this latitude: \(coordinate?.latitude) and longitude: \(coordinate?.longitude)")
        }
        
    } catch let error as NSError {
        print("Fetch error: \(error), \(error.userInfo)")
    }
    
    
}

func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    // if we're in the process or restoring the map region, do not save
    // otherwise save the region since it changed
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










}

