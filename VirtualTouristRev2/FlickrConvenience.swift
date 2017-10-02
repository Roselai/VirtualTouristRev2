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

    
}








