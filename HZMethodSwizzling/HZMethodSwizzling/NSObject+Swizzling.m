//
//  NSObject+Swizzling.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/8.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "NSObject+Swizzling.h"
#import <objc/runtime.h>

@implementation  NSObject (Swizzling)

+ (void)load
{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(swizzled_viewWillAppear);
        
        Class class = [self class];
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod)
        {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        }
        else
        {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
    });
}

- (void)swizzled_viewWillAppear
{
//    NSLog(@"swizzled object the method!");
//     调用旧的实现。因为它们已经被替换了
//        [self swizzled_viewWillAppear];
}

@end


