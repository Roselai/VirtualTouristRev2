//
//  FlickrConstants.swift
//  Virtual Tourist
//
//  Created by Shukti Shaikh on 8/22/16.
//  Copyright © 2016 Shukti Shaikh. All rights reserved.
//

import Foundation


    
    // MARK: - Constants
    
    struct Constants {
        
        // MARK: Flickr
        struct Flickr {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
        }
        
        struct FlickrMethod {
            static let SearchMethod = "flickr.photos.search"
        }
        
        
        // MARK: Flickr Parameter Keys
        struct FlickrParameterKeys {
             static let Method = "method"
             static let APIKey = "api_key"
            static let Extras = "extras"
             static let Format = "format"
            static let NoJSONCallback = "nojsoncallback"
            static let Latitude = "lat"
             static let Longitude = "lon"
            static let Page = "page"
            static let PerPage = "per_page"
            static let PhotoSearchRadius = "radius"
        }
        
        // MARK: Flickr Parameter Values
        struct FlickrParameterValues {
            static let APIKey = "485a19bf9fd9de124cfc2d85a0c66186"
            static let ResponseFormat = "json"
            static let DisableJSONCallback = "1" /* 1 means "yes" */
            static let MediumURL = "url_m"
            static let ResultLimit = "50"
            static let PhotoSearchRadius = "1"
            static let Page = "\(arc4random_uniform(UInt32(4000/Int(Constants.FlickrParameterValues.ResultLimit)!)))"
        }
        
        // MARK: Flickr Response Keys
        struct FlickrResponseKeys {
            static let Photos = "photos"
            static let Photo = "photo"
            static let MediumURL = "url_m"
            static let MaxPage = "pages"
            static let Title = "title"
            static let ID = "id"
            static let ImagePath = "url_m"
        }
        
        // MARK: Flickr Response Values
        struct FlickrResponseValues {
            static let OKStatus = "ok"
        }
        
    }
