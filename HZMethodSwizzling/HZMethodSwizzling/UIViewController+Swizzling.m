//
//  UIViewController+Swizzling.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/8.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "UIViewController+Swizzling.h"
#import <objc/runtime.h>

@implementation  UIViewController (Swizzling)

//+ (void)load
//{
// 
//
//
//    
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//   
//        
//        SEL originalSelector = @selector(viewWillAppear:);
//        SEL swizzledSelector = @selector(swizzled_viewWillAppear);
//        
//        Class class = [self class];
//        /** 获取实例方法
//         如果是类方法使用: Method originalMethod = class_getClassMethod(class, originalSelector);
//         **/
//        Method originalMethod = class_getInstanceMethod(class, originalSelector);
//        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
//        
//     
//        /**
//         作一个判断，检测 self 是否已经有了 originalSelector 方法。
//         同时,如果没有这个方法，就会添加一个 SEL 为 originalSelector 的方法，并将 swizzledSelector 的实现赋给它。
//         这时候，originalSelector 名字是 SEL 的名字，但实际上 imp 是指向 swizzledSelector。完成 originalSelector 的替换
//         **/
//        BOOL didAddMethod =
//        class_addMethod(class,
//                        originalSelector,
//                        method_getImplementation(swizzledMethod),
//                        method_getTypeEncoding(swizzledMethod));
//        
//        if (didAddMethod)
//        {   //self 添加 originalSelector 成功
//            //self 把 SEL 为 swizzledSelector  的方法，替换为 originalSelector。完成 swizzledSelector 的替换

//            class_replaceMethod(class,
//                                swizzledSelector,
//                                method_getImplementation(originalMethod),
//                                method_getTypeEncoding(originalMethod));
//        }
//        else
//        {   //self 添加 originalSelector 失败,已经有了 originalSelector,直接交换方法实现
//            method_exchangeImplementations(originalMethod, swizzledMethod);
//        }
//        
//    });
//}
//
//- (void)swizzled_viewWillAppear
//{
//    NSLog(@"swizzled the method!");
//    // 调用旧的实现。因为它们已经被替换了
//    [self swizzled_viewWillAppear];
//}

@end

