//
//  FlickrConvenience.swift
//  Virtual Tourist 4.0
//
//  Created by Shukti Shaikh on 11/2/16.
//  Copyright © 2016 Shukti Shaikh. All rights reserved.
//

import Foundation
import CoreData

extension FlickrClient {
    
    
    
    func getPhotosForPin(pin: Pin, completionHandlerForSearchPhotos:@escaping (_ photos: [[String:AnyObject]]?, _ error: NSError?)->Void) {
        
        
        let parameters = [
            Constants.FlickrParameterKeys.Latitude: "\(pin.latitude)",
            Constants.FlickrParameterKeys.Longitude: "\(pin.longitude)",
            Constants.FlickrParameterKeys.PhotoSearchRadius: Constants.FlickrParameterValues.PhotoSearchRadius,
            Constants.FlickrParameterKeys.Page: Constants.FlickrParameterValues.Page,
            Constants.FlickrParameterKeys.PerPage: Constants.FlickrParameterValues.ResultLimit
        ]
        
        let method = Constants.FlickrMethod.SearchMethod
        
        
        _ = self.taskForGETMethod(method: method, parameters: parameters as [String : AnyObject]?) { (result, error) in
            guard error == nil else {
                completionHandlerForSearchPhotos(nil, error)
                return
            }
            
            guard result != nil else {
                print("no data was returned by the request")
                return
            }
            
            if let result = result {
                
                let photosDictionary = result[Constants.FlickrResponseKeys.Photos] as! [String:AnyObject]
                let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as! [[String:AnyObject]]
                completionHandlerForSearchPhotos(photosArray, nil)
                
            }
            
            
        }
    }
    
    
    func fetchPhotos(pin: Pin, inContext context: NSManagedObjectContext) {
        
        let parameters = [
            Constants.FlickrParameterKeys.Latitude: "\(pin.latitude)",
            Constants.FlickrParameterKeys.Longitude: "\(pin.longitude)",
            Constants.FlickrParameterKeys.PhotoSearchRadius: Constants.FlickrParameterValues.PhotoSearchRadius,
            Constants.FlickrParameterKeys.Page: Constants.FlickrParameterValues.Page,
            Constants.FlickrParameterKeys.PerPage: Constants.FlickrParameterValues.ResultLimit
        ]
        
        let method = Constants.FlickrMethod.SearchMethod
        
        _ = self.taskForGETMethod(method: method, parameters: parameters as [String : AnyObject]?) { (result, error) in
            
            // GUARD: was there an error?
            guard error == nil else {
                print("Network request returned with error: \(error), \(error?.userInfo)")
                return
            }
            
            // Did we receive photos
            guard result != nil else {
                print("Photos returned is nil")
                return
            }
            
            if let result = result {
                
                let photosDictionary = result[Constants.FlickrResponseKeys.Photos] as! [String:AnyObject]
                let photosArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as! [[String:AnyObject]]
                
                // Process the photos dictionary asynchronously on the main thread
                DispatchQueue.main.async {
                    context.performAndWait() {
                        
                        // process the photos in the returned dictionary
                        for photoDict in photosArray {
                            let photo = Photo(context: context)
                            photo.title = photoDict[Constants.FlickrResponseKeys.Title] as? String
                            photo.photoID = photoDict[Constants.FlickrResponseKeys.ID] as? String
                            photo.remoteURL = photoDict[Constants.FlickrResponseKeys.ImagePath] as? String
                            photo.pin = pin
                            
                            

                            
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
                                        
                                        
                                        photo.image = result as NSData?
                                        print("image data retreived \(photo.image)")
                                        
                                        
                                        
                                    })
                                    
                                }
                                
                                
                            }
                            
                        }
                        do {
                            try context.save()
                        } catch let error as NSError {
                            print("Could not save: \(error), \(error.userInfo)")
                        }
                        
                        
                    }
                    
                    
                }
                
                
            }
            
            
        }
        
        
        
    }
    
    
}








