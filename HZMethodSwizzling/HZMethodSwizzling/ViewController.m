//
//  ViewController.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/8.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "ViewController.h"
#import "HZCustomView.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (IBAction)tapMainButton:(id)sender {
    HZCustomView *subView =[HZCustomView new];
    [subView doSomething];
}

- (IBAction)tapNotMainButton:(id)sender {
    
    HZCustomView *subView =[HZCustomView new];
 
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        [subView doSomething];
         
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
