//
//  UIImage+Rotation.h
//  Pods
//
//  Created by Geoff Davis on 3/11/15.
//
//

#import <UIKit/UIKit.h>

@interface UIImage (Rotation)

+ (UIImage *)rotateImageToFlaggedOrientation:(UIImage *)image;

+ (UIImage *)rotateImage:(UIImage *)image toOrientation:(UIImageOrientation)imageOrientation;

@end
