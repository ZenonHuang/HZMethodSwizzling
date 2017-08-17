//
//  HZUIChecker.m
//  HZMethodSwizzling
//
//  Created by mewe on 2017/8/9.
//  Copyright © 2017年 zenon. All rights reserved.
//

#import "HZUIChecker.h"
#import <objc/runtime.h>
#import <objc/message.h>

#import <dlfcn.h>
#import <mach-o/ldsyms.h>

static void HZUICheckerForwardInvocation(__unsafe_unretained id slf, SEL selector, NSInvocation *invocation);

@implementation HZUIChecker

+(void)load{
    
    NSArray *ignoreClasses = @[@"IQToolbar",@"GetGameDetailResponse"];
    
    /** step1 获取程序文件所有 UI 类（不包括系统框架等,可由开发者创建和修改的class） **/
    unsigned int count;
    const char **classes;
    Dl_info info;
    
    //获取app的路径
    dladdr(&_mh_execute_header, &info);
    //返回当前运行的app的所有类的名字，并传出个数
    classes = objc_copyClassNamesForImage(info.dli_fname, &count);
    
    NSMutableArray *needClassList = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        NSString *className = [NSString stringWithCString:classes[i] encoding:NSUTF8StringEncoding];
        Class class = NSClassFromString(className);
        
        
        BOOL needIgnore = NO;
        
        for (NSString  *ignoreClassName in ignoreClasses) {
            if ([ignoreClassName isEqualToString:className]) { //部分出现 'Class xxx not defined' 的 exception
                needIgnore = YES;
                continue;
            }
            
        }
        
        if (!needIgnore) {
            for (NSString  *ignoreClassName in ignoreClasses) {
                Class ignoreClass = NSClassFromString(ignoreClassName);
                if ([class  isSubclassOfClass:ignoreClass]) {//是否为忽略类，或者忽略类的子类
                    needIgnore = YES;
                    continue;
                }
            }
        }
        
        if (!needIgnore ) {//并不在忽略类中
//            if ([HZUIChecker checkUISubClass:class]) {  //检测是否属于UIView 
//                NSLog(@"UI SubClass -- %@", NSStringFromClass(class));
//                [needClassList addObject:class];
//            }
            if ([class isSubclassOfClass:UIView.class]) {  //检测是否属于UIView
                
                if([className  isEqualToString:NSStringFromClass(object_getClass(class))]){ //比较 get 到的 isa 和目前的 isa 是否一致
                    NSLog(@"UI SubClass -- %@", NSStringFromClass(class));
                    [needClassList addObject:class];
                };
                
              
            }
        }
       
    }
    
    //step2 对每一个类的 method 进行获取
    for (Class class in needClassList) {
        [HZUIChecker addMethod:class];
    }
    
    free(classes);
}



+(void)addMethod:(Class)class{
    
    NSMutableArray *ignoreMethods = [NSMutableArray arrayWithArray:@[@"retain", @"release", @"dealloc", @".cxx_destruct",
                                                                     @"autorelease", @"forwardInvocation:"]];
    
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
    
    for(int i = 0; i < propertyCount; i++)
    {
        objc_property_t property = properties[i];
        const char *name =property_getName(property);
        [ignoreMethods addObject:@(name)];

    }
    free(properties);
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(class, &methodCount);
    
    for (int i = 0; i < methodCount; i++)
    {
        Method method = methodList[i];
        SEL selector  = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        BOOL needIgnore = NO;
        for (NSString *ignoreMethod in ignoreMethods) {
            if ([methodName isEqualToString:ignoreMethod]) {
                needIgnore = YES;
                continue;
            }
        }
        
        
        
        if (!needIgnore )
        {
            //是否响应,并且父类是否没有此seletor
            BOOL respondsToSelector = [HZUIChecker checkUISubClass:class selector:selector];
            
            if (respondsToSelector) {
                NSLog(@"YES %@",NSStringFromSelector(selector));
            }else{
                NSLog(@"NO %@",NSStringFromSelector(selector));
            }
            
            if (!respondsToSelector) {
                return ;
            }
            
            //得到实例方法对应 IMP
            Method targetMethod = class_getInstanceMethod(class, selector);
            IMP targetMethodIMP = method_getImplementation(targetMethod);
            if (!isMsgForwardIMP(targetMethodIMP)) {//IMP 是否已经存在了
                 [HZUIChecker replaceMethod:class methodName:methodName];
            }else{
                NSLog(@"already imp %@",methodName);
            }
           
        }
        
    }
    
    free(methodList);
}



/**
 检测方法是否可用作转发：
 1.父类没有此方法
 2.自身可以对此进行响应

 @param class 类
 @param selector 方法
 @return NO 表示不可以用，YES 表示可以
 */
+(BOOL)checkUISubClass:(Class)class selector:(SEL)selector{
    
    if (!class_getSuperclass(class)) { //没有有父类
        if ([class instancesRespondToSelector:selector]) {//自身可以响应
            return YES;
        }
        return NO;
    }
    
    
    if (class == [UIView class]) { //UIView 本身
        if ([class instancesRespondToSelector:selector]) {//自身可以响应
            return YES;
        }
        return NO;
    }
    
    
   BOOL isUI = NO;
    
   if ([class_getSuperclass(class) instancesRespondToSelector:selector]) {//父类可以响应
       if ([class instancesRespondToSelector:selector]) {//自身也可以响应，所以父类优先，本身不响应
           return NO;
       }
   }else{
       if ([class instancesRespondToSelector:selector]) {//父类不响应，本身响应
           return YES;
       }
   }
 
    
    isUI = [HZUIChecker checkUISubClass:class_getSuperclass(class) selector:selector];
    
    return isUI;
}

+(void)replaceMethod:(Class) cls methodName:(NSString *)selectorName
{
    
    NSLog(@"replace class %@ selector %@",NSStringFromClass(cls),selectorName);
    SEL selector = NSSelectorFromString(selectorName);

    Method method = class_getInstanceMethod(cls, selector);
    const char *typeDescription = (char *)method_getTypeEncoding(method);
    
    /** 先保存方法原始的IMP **/
    IMP originalImp = class_getMethodImplementation(cls, selector);
    
    //得到 _objc_msgForward 或者 _objc_msgForward_stret
    IMP msgForwardIMP = getMsgForwardIMP(cls, selector);
    
    //msgForwardIMP 对 selector 做 replace. 将进入消息转发,调用forwardInvocation:
    class_replaceMethod(cls, selector, msgForwardIMP, typeDescription);
    
    //myForwardInvocation 的 IMP 替换 forwardInvocation 的 IMP ，消息转发进入 myForwardInvocation
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)HZUICheckerForwardInvocation)
    {   //将forwardInvocation:替换成我们自定义的方法myForwardInvocation
        //这样在消息重定位时便会运行到myForwardInvocation，在这个方法里做线程的判断处理。
        class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)HZUICheckerForwardInvocation, typeDescription);
    }
    
    //是否能响应方法
    if (class_respondsToSelector(cls, selector))
    {
        //将原始 IMP 重新添加到类中，原始方法名加前缀 ORIG_ 标识
        
//        NSString *originalSelectorName = [NSString stringWithFormat:@"ORIG_%@_%@",NSStringFromClass(cls),selectorName];
        NSString *originalSelectorName =  [NSString stringWithFormat:@"ORIG_%@",selectorName];
        SEL originalSelector = NSSelectorFromString(originalSelectorName);
        
        if(!class_respondsToSelector(cls, originalSelector))
        {
            class_addMethod(cls, originalSelector, originalImp, typeDescription);
        }
    }
}

static BOOL isMsgForwardIMP(IMP impl) {
    return impl == _objc_msgForward
#if !defined(__arm64__)
    || impl == (IMP)_objc_msgForward_stret
#endif
    ;
}

static IMP getMsgForwardIMP(Class class,SEL selector){
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    Method method = class_getInstanceMethod(class, selector);
    const char *encoding = method_getTypeEncoding(method);
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);
            
            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
#if defined(__LP64__) && __LP64__
            if (valueSize == 16) {
                methodReturnsStructValue = NO;
            }
#endif
        } @catch (__unused NSException *e) {}
    }
    if (methodReturnsStructValue) {
        msgForwardIMP = (IMP)_objc_msgForward_stret;
    }
#endif
    return msgForwardIMP;
}
static void HZUICheckerForwardInvocation(__unsafe_unretained id slf, SEL selector, NSInvocation *invocation)
{
    
    if (![HZUIChecker isMainQueue])
    {
        NSLog(@"%@ ",[NSThread callStackSymbols]);
        NSCAssert([HZUIChecker isMainQueue], @"--- HZUIChecker --- 操作不在主队列");
    }
    
    //正常执行的时候回通过ORIG_前缀名获取到当前函数的原始方法
    //此时用原始方法继续运行.和正常的调用一致。
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    Class class = object_getClass(invocation.target);
    
//    NSString *origSelectorName = [NSString stringWithFormat:@"ORIG_%@_%@",NSStringFromClass(class),selectorName];
    NSString *origSelectorName = [NSString stringWithFormat:@"ORIG_%@",selectorName];
    SEL origSelector = NSSelectorFromString(origSelectorName);


    
    if ([class instancesRespondToSelector:origSelector]) { //实例能否响应交换后的方法
        invocation.selector = origSelector;
        [invocation invoke];
    }else{
        //失败则尝试用原来的方法
        SEL originalForwardInvocationSEL = invocation.selector ;
        if ([slf respondsToSelector:originalForwardInvocationSEL]) {
           //重新走消息转发
           ((void( *)(id, SEL, NSInvocation *))objc_msgSend)(slf, originalForwardInvocationSEL, invocation);
    
         }else {
           [slf doesNotRecognizeSelector:invocation.selector];
         }

        
    }


}

+ (BOOL)isMainQueue {
    static const void* mainQueueKey = @"mainQueue";
    static void* mainQueueContext = @"mainQueue";
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_set_specific(dispatch_get_main_queue(), mainQueueKey, mainQueueContext, nil);
    });
    
    return dispatch_get_specific(mainQueueKey) == mainQueueContext;
}
@end
