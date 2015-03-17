//
//  JPSImageMask.m
//  Pods
//
//  Created by Smule on 3/12/15.
//
//

#import "JPSImageMask.h"

@implementation JPSImageMask

- (id)initWithFrame:(CGRect)frame
{
    if ( self = [super initWithFrame:frame] )
    {
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}



- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor( context, [UIColor blackColor].CGColor );
    CGContextFillRect( context, rect );
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    
    CGFloat smallestDimension = MIN(rect.size.width, rect.size.height);
    
    CGFloat maskRadius = smallestDimension * 4 / 9;

    CGRect pathRect = CGRectMake(rect.size.width/2-maskRadius, rect.size.height/2-maskRadius, maskRadius*2, maskRadius*2);
    CGContextSetFillColorWithColor( context, [UIColor whiteColor].CGColor );
    CGContextFillEllipseInRect( context, pathRect );

}
 



@end
