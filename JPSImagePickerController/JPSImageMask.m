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
        //self.alpha = 0.4;
    }
    return self;
}



- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor( context, [UIColor colorWithRed:1 green:0 blue:1 alpha:.4].CGColor );
    //CGContextSetFillColorWithColor( context, [UIColor blackColor].CGColor );
    CGContextFillRect( context, rect );
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    
    CGFloat maskRadius = rect.size.height * 4 / 9;

    CGRect pathRect = CGRectMake(rect.size.width/2-maskRadius, rect.size.height/2-maskRadius, maskRadius*2, maskRadius*2);
    CGContextSetFillColorWithColor( context, [UIColor whiteColor].CGColor );
    CGContextFillEllipseInRect( context, pathRect );

}
 



@end
