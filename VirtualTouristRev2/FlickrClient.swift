//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Shukti Shaikh on 8/22/16.
//  Copyright © 2016 Shukti Shaikh. All rights reserved.
//

import Foundation


class FlickrClient: NSObject {
    

    // shared session
    var session = URLSession.shared
    
    
    // MARK: Initializers
    
    override init() {
        super.init()
    }
    
     func taskForGETMethod(method: String, parameters: [String: AnyObject]?, completionHandlerForGET: @escaping (_ result: AnyObject?, _ error: NSError?) -> Void) -> URLSessionDataTask {
        
        /* 1. Set the parameters */
        
        
        /* 2/3. Build the URL, Configure the request */
        let url = FlickrClient.flickrURLFromParameters(method: method, parameters: parameters)
        let request = URLRequest(url: url)
        
        /* 4. Make the request */
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            
            func sendError(error: String) {
                print(error)
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForGET(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
            }
            
            /* GUARD: Was there an error? */
            let errorString = error?.localizedDescription
            guard (error == nil) else {
                //sendError("There was an error with your request")
                sendError(error: "Your request could not be completed: \(errorString!)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                sendError(error: "Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                sendError(error: "No data was returned by the request!")
                return
            }
            
            /* 5/6. Parse the data and use the data (happens in completion handler) */
            self.convertDataWithCompletionHandler(data: data, completionHandlerForConvertData: completionHandlerForGET )
        }
        
        
        /* 7. Start the request */
        task.resume()
        
        return task
        
    }
    
     func downloadimageData(photoURL: URL, completionHandlerForDownloadImageData: @escaping (_ data: Data?, _ error: NSError?)-> Void) -> URLSessionDataTask {
        
        let request = URLRequest(url: photoURL)
        let task = session.dataTask(with: request) { (data, response, error) in
            
            func sendError(error: String) {
                print(error)
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForDownloadImageData(nil, NSError(domain: "taskForGETMethod", code: 1, userInfo: userInfo))
            }
            
            /* GUARD: Was there an error? */
            let errorString = error?.localizedDescription
            guard (error == nil) else {
                //sendError("There was an error with your request")
                sendError(error: "Your request could not be completed: \(errorString!)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                sendError(error: "Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                sendError(error: "No data was returned by the request!")
                return
            }
            
            completionHandlerForDownloadImageData(data, nil)
        }
        task.resume()
        return task
    }

    
    
    
    // given raw JSON, return a usable Foundation object
    private func convertDataWithCompletionHandler(data: Data, completionHandlerForConvertData: (_ result: AnyObject?, _ error: NSError?) -> Void) {
        
        var parsedResult: AnyObject!
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandlerForConvertData(nil, NSError(domain: "convertDataWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        
        completionHandlerForConvertData(parsedResult, nil)
    }
    
    
    
    // MARK: Helper for Creating a URL from Parameters
    
    private static func flickrURLFromParameters(method: String, parameters: [String:AnyObject]?) -> URL {
        
        var components = URLComponents()
        var queryItems = [URLQueryItem]()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        
        
        let baseParams = [Constants.FlickrParameterKeys.APIKey : Constants.FlickrParameterValues.APIKey ,
                          Constants.FlickrParameterKeys.Method : method,
                          Constants.FlickrParameterKeys.Extras : Constants.FlickrParameterValues.MediumURL ,
                          Constants.FlickrParameterKeys.Format : Constants.FlickrParameterValues.ResponseFormat ,
                          Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback ]
        
        for (key, value) in baseParams {
            let item = URLQueryItem(name: key, value: value)
            queryItems.append(item)
            
        }
        
        if let additionalParams = parameters {
            for (key, value) in additionalParams {
                let item = URLQueryItem(name: key, value: value as? String)
                queryItems.append(item)
            }
        }
        
        components.queryItems = queryItems as [URLQueryItem]?
        return components.url!
    }
    
    
    
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
    
}

