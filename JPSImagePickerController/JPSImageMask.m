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
        //self.backgroundColor = [UIColor greenColor];
        //self.alpha = 0.4;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect pathRect = CGRectMake(rect.size.width/2-120, rect.size.height/2-200, 240, 240);
    CGContextSetFillColorWithColor( context, [UIColor blueColor].CGColor );
    CGContextFillEllipseInRect( context, pathRect );
}


@end
