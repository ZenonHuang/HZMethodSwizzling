//
//  ViewController.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/8.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
  
    
    NSString *originalString = [NSString stringWithFormat:@"viewWillAppear:"];;
    SEL originalSelector = NSSelectorFromString(originalString);
    
    NSString *swizzledString = [NSString stringWithFormat:@"swizzled_viewWillAppear"];;
    SEL swizzledSelector = NSSelectorFromString(swizzledString);
    
    NSObject *obj = [NSObject new];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [obj performSelector:swizzledSelector withObject:nil];
//    [obj performSelector:originalSelector withObject:nil];
//    [self performSelector:swizzledSelector withObject:nil];
//    [self performSelector:originalSelector withObject:nil];

#pragma clang diagnostic pop

    
    
    Class class = [self class];
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

    NSLog(@"\n swizzled :%zd \n original :%zd ",swizzledMethod,originalMethod);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
