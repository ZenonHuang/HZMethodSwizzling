//
//  HZCustomView.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/9.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "HZCustomView.h"


@implementation HZCustomView

-(void)doSomething{
 
    NSLog(@"do do do ");
  
}
- (CGPoint)funcToSwizzleReturnPoint:(CGPoint)point
{
       NSLog(@"cgPoint");
    return CGPointZero;
}
@end
