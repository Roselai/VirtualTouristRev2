//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Shukti Shaikh on 9/4/17.
//  Copyright © 2017 Shukti Shaikh. All rights reserved.
//
import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var spinner: UIActivityIndicatorView!
    
//let defaultImage = UIImage(named: "placeHolder")
    
    func update(with image: UIImage?) {
        if let imageToDisplay = image {
            
            spinner.stopAnimating()
            imageView.image = imageToDisplay
            
        } else {
            spinner.startAnimating()
            imageView.image = nil
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        update(with: nil)
        
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        update(with: nil)
        
    }
}
