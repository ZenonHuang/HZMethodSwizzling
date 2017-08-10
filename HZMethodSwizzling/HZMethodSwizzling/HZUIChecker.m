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
    /** step1 获取程序文件所有 UI 类（不包括系统框架等,可由开发者创建和修改的class） **/
    unsigned int count;
    const char **classes;
    Dl_info info;
    
    //1.获取app的路径
    dladdr(&_mh_execute_header, &info);
    
    //2.返回当前运行的app的所有类的名字，并传出个数
    //classes：二维数组 存放所有类的列表名称
    //count：所有的类的个数
    classes = objc_copyClassNamesForImage(info.dli_fname, &count);
    
    NSMutableArray *needClassList = [NSMutableArray new];
    for (int i = 0; i < count; i++) {
        //3.遍历并打印，转换Objective-C的字符串
        NSString *className = [NSString stringWithCString:classes[i] encoding:NSUTF8StringEncoding];
        Class class = NSClassFromString(className);
        NSLog(@"every class name = %@", class);
        //检测 class 是否为 UIView 或 UIView 子类
        if ([HZUIChecker checkUISubClass:class]) {
            NSLog(@"UI SubClass -- %@", NSStringFromClass(class));
            [needClassList addObject:class];
        }
    }
    //step2 对每一个类的 method 进行获取
    for (Class class in needClassList) {
        [HZUIChecker exchangeMethod:class];
    }
    //step3 交换 method,即修改 method,加入检测主队列（非主线程，主线程不一定安全）代码
    
    free(classes);
}

+(BOOL)checkUISubClass:(Class)class{
    
    if (!class_getSuperclass(class)) { //没有有父类
        return NO;
    }
    
    BOOL isUI = NO;
    
    if (class_getSuperclass(class) == [UIView class]){ //父类是否 UIView
        return YES;
    }
    
    isUI = [HZUIChecker checkUISubClass:class_getSuperclass(class)];
    
    return isUI;
}

+(void)exchangeMethod:(Class)class{
    
    NSMutableArray *ignoreMethods = [NSMutableArray arrayWithArray:@[@"retain", @"release", @"dealloc", @".cxx_destruct"]];
    
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
    
    for(int i = 0; i < propertyCount; i++)
    {
        objc_property_t property = properties[i];
        const char *name =property_getName(property);
        [ignoreMethods addObject:@(name)];
        printf("property name %d : %s\n", i, name);
    }
    free(properties);
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(class, &methodCount);
    
    for (int i = 0; i < methodCount; i++)
    {
        Method method = methodList[i];
        NSString *methodName = NSStringFromSelector(method_getName(method));
        
        BOOL needIgnore = NO;
        for (NSString *ignoreMethod in ignoreMethods) {
            if ([methodName isEqualToString:ignoreMethod]) {
                needIgnore = YES;
                continue;
            }
        }
        
        if (!needIgnore)
        {
            [HZUIChecker replaceMethod:class methodName:methodName];
        }
        
    }
    
    free(methodList);
}

+(void)replaceMethod:(Class) cls methodName:(NSString *)selectorName
{
    SEL selector = NSSelectorFromString(selectorName);
    
    Method method = class_getInstanceMethod(cls, selector);
    const char *typeDescription = (char *)method_getTypeEncoding(method);
    
    /** 保存方法原始的IMP **/
    IMP originalImp = class_getMethodImplementation(cls, selector);
    
    //_objc_msgForward用于消息转发
    //当将原来的IMP替换成_objc_msgForward时，直接进行消息的转发，调用forwardInvocation:
    IMP msgForwardIMP = getMsgForwardIMP(cls, selector);
    
    //替换 selector. 将使用 msgForwardIMP 的 IMP
    class_replaceMethod(cls, selector, msgForwardIMP, typeDescription);
    
    //判断，如果 forwardInvocation: 方法的 IMP 和 myForwardInvocation 的 IMP 不一样，则 replace
    if (class_getMethodImplementation(cls, @selector(forwardInvocation:)) != (IMP)HZUICheckerForwardInvocation)
    {   //将forwardInvocation:替换成我们自定义的方法myForwardInvocation
        //这样在消息重定位时便会运行到myForwardInvocation，在这个方法里做线程的判断处理。
        class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)HZUICheckerForwardInvocation, typeDescription);
    }
    
    //是否能响应方法
    if (class_respondsToSelector(cls, selector))
    {
        //最终将原始IMP重新添加到类中，IMP的方法名称为原始方法名前加前缀ORIG_
        NSString *originalSelectorName = [NSString stringWithFormat:@"ORIG_%@", selectorName];
        SEL originalSelector = NSSelectorFromString(originalSelectorName);
        
        if(!class_respondsToSelector(cls, originalSelector))
        {
            class_addMethod(cls, originalSelector, originalImp, typeDescription);
        }
    }
}


static IMP getMsgForwardIMP(Class class,SEL selector){
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
    // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
    // https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
    // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
    Method method = class_getInstanceMethod(class, selector);
    const char *encoding = method_getTypeEncoding(method);
    
    
    //    NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:typeDescription];
    //    if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {//通过检测对应字符串判断有问题的struct
    //        msgForwardIMP = (IMP)_objc_msgForward_stret;
    //    }
    
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);//取得对象的大小
            
            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (__unused NSException *e) {}
    }
    if (methodReturnsStructValue) { //对于某些架构某些 struct，返回值必须使用 _objc_msgForward_stret 代替 _objc_msgForward
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
        NSCAssert([HZUIChecker isMainQueue], @"操作不在主队列");
    }
    
    //正常执行的时候回通过ORIG_前缀名获取到当前函数的原始方法
    //此时用原始方法继续运行.和正常的调用一致。
    NSString *selectorName = NSStringFromSelector(invocation.selector);
    NSString *origSelectorName = [NSString stringWithFormat:@"ORIG_%@", selectorName];
    SEL origSelector = NSSelectorFromString(origSelectorName);
    
    invocation.selector = origSelector;
    [invocation invoke];
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
