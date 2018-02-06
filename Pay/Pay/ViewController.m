//
//  ViewController.m
//  Pay
//
//  Created by 1111 on 2018/2/6.
//  Copyright © 2018年 ljl. All rights reserved.
//
/*
 支付：内购，第三方支付（微信，支付宝，银联 applepay）
 第三方流程：总之一句话将一些参数加密签名以后发送给第三方支付app发起支付
 
 当用户触发购买按钮-app向webserver发送相应支付参数（微信支付参数等）
 获取appserver支付参数--跳转到相应支付平台调用发起支付
 第三方支付平台向支付服务器发起支付请求
 第三方支付服务器通知第三方客户端支付结果，也会将支付结果通知给appserver
 第三方支付客户端将回调结果发送给app（第三方支付回调有时候不准我们必须要向我们支付的服务器询问本次结果）
 步骤包含服务器
 
 第一步：配置项目
 第二步：统一下单包含二次签名（服务器）
 第三步：客户端接收服务器参数发起微信支付
 第四步：支付完成客户端向服务器询问支付结果
 
 */
#define MCH_ID @"asdfsdhjfasjdfhs"//商户号
#define API_KEY @"asdfhasdjfhalsff"//密钥
//微信支付的appid不是分享的
#define APP_KEY @"wxeiXinPayDemo123"
//统一下单接口
#define HTTP @"https://api.mch.weixin.qq.com/pay/unifiedorder"//

#import "ViewController.h"
#import <WXApi.h>

#import <AFNetworking.h>

//xml解析库
#import "ApiXml.h"

/**
 *  获取IP相关参数
 */
#import "CommonCrypto/CommonDigest.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"


@interface ViewController ()<WXApiDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    
    NSArray *AR = @[@"微信支付"];
    
    for (NSInteger i=0; i<AR.count; i++) {
        UIButton *btn = [[UIButton alloc]initWithFrame:CGRectMake(self.view.frame.size.width/2-60,100+40*i, 120, 30)];
        btn.tag = 100+i;
        [btn setTitle:AR[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(btnOnlick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
        
    }
   
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)btnOnlick:(UIButton *)btn{
    
    switch (btn.tag) {
        case 100:
            [self WxPay];
            break;
            
        default:
            break;
    }
    
    
}

/**
 我们来做本地统一下单和二次签名工作
 如果正式项目还是在后台生成
 //统一下单 链接https://api.mch.weixin.qq.com/pay/unifiedorder
 
 
 这一步是服务器来做
 统一下单字端：
 以下是必填的
 appid:应用id
 mch_id：商户号
 device_info:设备号
 nonce_str:随机字符串
 sign:签名
 body:商品描述
 out_trade_no：商户订单号
 total_fee:总金额
 spbill_create_ip:终端ip
 notyfy_url:通知地址
 trade_trpe:交易类型
 ---------------------------
 
 */
-(void)WxPay{
    
    //设备号
    NSString *device =[[UIDevice currentDevice] identifierForVendor].UUIDString;
    //价格 微信是按分来计算的比如商品300，那么就是300*100
    NSString *price = @"300000";
    //订单标题 展示给用户
    NSString *orderName = @"微信支付";
     //订单类型
    NSString *orderType = @"APP";
    //发起支付的设备ip地址
    NSString *ordeIp =  [self getIP:YES];
    NSLog(@"%@",ordeIp);
    
    //生成随机数串
    //time(0)得到当前时间值
    //而srand()函数是种下随机种子数方便调用rand来得到随机数
    srand((unsigned)time(0));
     NSString *noncestr  = [NSString stringWithFormat:@"%d", rand()];
    
    //订单号。(随机的可以直接用时间戳)
    NSString *orderNO   = [self timeStamp];
    
    
    NSMutableDictionary *packageParams = [NSMutableDictionary dictionary];
    
  
    
    [packageParams setObject:APP_KEY  forKey:@"appid"];       //开放平台appid
    [packageParams setObject: MCH_ID  forKey:@"mch_id"];      //商户号
    [packageParams setObject: device  forKey:@"device_info"]; //支付设备号或门店号
    [packageParams setObject: noncestr     forKey:@"nonce_str"];   //随机串
    [packageParams setObject: orderType    forKey:@"trade_type"];  //支付类型，固定为APP
    [packageParams setObject: orderName    forKey:@"body"];        //订单描述，展示给用户
    NSString * str = @"www.baidu.com";//[NSString stringWithFormat:@"%@",[payDic objectForKey:@"notify_url"]];
    [packageParams setObject: str  forKey:@"notify_url"];  //支付结果异步通知
    [packageParams setObject: orderNO      forKey:@"out_trade_no"];//商户订单号
    [packageParams setObject: ordeIp      forKey:@"spbill_create_ip"];//发器支付的机器ip
    [packageParams setObject: price   forKey:@"total_fee"];       //订单金额，单位为分
    
    //获取预支付订单
     NSString * prePayID = [self getPrePayId:packageParams];
    
    /*----二次签名并且发起微信支付--------------------------*/
      NSString    *package, *time_stamp, *nonce_str;
    //设置支付参数
    time_t now;
    time(&now);
    time_stamp  = [NSString stringWithFormat:@"%ld", now];//时间戳
     nonce_str = [self md5:time_stamp];//随机字符串（直接用时间戳来生成就可以了）
    
     package         = @"Sign=WXPay";
    
    NSMutableDictionary *signParams = [NSMutableDictionary dictionary];//用于二次签名的参数
    [signParams setObject: APP_KEY  forKey:@"appid"];
    [signParams setObject: MCH_ID  forKey:@"partnerid"];
    [signParams setObject: nonce_str    forKey:@"noncestr"];
    [signParams setObject: package      forKey:@"package"];
    [signParams setObject: time_stamp   forKey:@"timestamp"];
    [signParams setObject: prePayID     forKey:@"prepayid"];
    
    //调起微信支付
    PayReq* req             = [[PayReq alloc] init];
    req.partnerId           = MCH_ID;
    req.prepayId            = prePayID;
    req.nonceStr            = nonce_str;
    req.timeStamp           = time_stamp.intValue;
    req.package             = package;
    
    req.sign                = [self createMd5Sign:signParams];//二次签名
    
    [WXApi sendReq:req];
    
    
    
    
#pragma mark---正式项目用下面这个
//     */
//    /*
//      一般为了安全以下值都是服务器给你传过来的
//     */
//    PayReq *req = [[PayReq alloc]init];
//
//    req.openID = @"有用户微信号和appid组成的唯一标示付，有与微信用户";
//    req.partnerId = @"商户号注册时给的";
//    req.prepayId = @"预支付订单，从服务器获取";
//    req.package = @"Sign=WXPay固定值";
//    req.nonceStr = @"随机串，防重发";
//    req.timeStamp = @"时间簇偶，放重发";
//    req.sign = @"商家微信开发平台文档对数据做的签名，可从服务器获取，也可以本地生产";
//    [WXApi sendReq:req];
    
    
}


/**
获取到prepay_id预支付订单号
要和微信支付后台交互
 @param pakeParams 字典
 @return 返回预支付订单号
 里面需求md5加密 排序等，微信支付后台交互 xml解析
 */
-(NSString *)getPrePayId:(NSMutableDictionary *)pakeParams{
    
   
   static NSString *aprepayid = nil;
    //按照微信支付接口来进行排序和加密然后将该字段传送给微信支付后台
    NSString *send = [self genPackage:pakeParams];
    
    AFHTTPSessionManager *session = [AFHTTPSessionManager manager];
    session.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    [session.requestSerializer setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
     [session.requestSerializer setValue:@"https://api.mch.weixin.qq.com/pay/unifiedorder" forHTTPHeaderField:@"SOAPAction"];
    
    [session.requestSerializer setQueryStringSerializationWithBlock:^NSString *(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error) {
        return send;
    }];
    
    [session POST:@"https://api.mch.weixin.qq.com/pay/unifiedorder" parameters:send constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        XMLHelper *xml  = [[XMLHelper alloc] init];
        //开始解析
        [xml startParse:responseObject];
        NSMutableDictionary *resParams = [xml getDict];
        NSLog(@"%@",resParams);
        //判断返回
        NSString *return_code   = [resParams objectForKey:@"return_code"];
        NSString *result_code   = [resParams objectForKey:@"result_code"];
        if ([return_code isEqualToString:@"SUCCESS"]) {
            //生成返回数据进行排序签名
            NSString *sign      = [self createMd5Sign:resParams ];
            NSString *send_sign =[resParams objectForKey:@"sign"];
            if ([sign isEqualToString:send_sign]) {
                if ([result_code isEqualToString:@"SUCCESS"]) {
                 aprepayid = [resParams objectForKey:@"prepay_id"];
                }
            }
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
    
    return aprepayid;
}
#pragma mark ---  获取package带参数的签名包
-(NSString *)genPackage:(NSMutableDictionary*)packageParams
{
    NSString *sign;
    NSMutableString *reqPars=[NSMutableString string];
    //给字符串生成签名
    sign = [self createMd5Sign:packageParams];
    //生成xml的package
    NSArray *keys = [packageParams allKeys];
    [reqPars appendString:@"<xml>\n"];
    for (NSString *categoryId in keys) {
        [reqPars appendFormat:@"<%@>%@</%@>\n", categoryId, [packageParams objectForKey:categoryId],categoryId];
    }
    [reqPars appendFormat:@"<sign>%@</sign>\n</xml>", sign];
    
    return [NSString stringWithString:reqPars];
}
#pragma mark ---  创建package签名
-(NSString*) createMd5Sign:(NSMutableDictionary*)dict
{
    NSMutableString *contentString  =[NSMutableString string];
    NSArray *keys = [dict allKeys];
    //按字母顺序排序
    NSArray *sortedArray = [keys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2 options:NSNumericSearch];
    }];
    //拼接字符串
    for (NSString *categoryId in sortedArray) {
        if (   ![[dict objectForKey:categoryId] isEqualToString:@""]
            && ![categoryId isEqualToString:@"sign"]
            && ![categoryId isEqualToString:@"key"]
            )
        {
            [contentString appendFormat:@"%@=%@&", categoryId, [dict objectForKey:categoryId]];
        }
        
    }
    //添加key字段
    [contentString appendFormat:@"key=%@", API_KEY];
    NSLog(@"%@",contentString);
    //得到MD5 sign签名
    NSString *md5Sign =[self md5:contentString];
    
    //输出Debug Info
    //    [self.debugInfo appendFormat:@"MD5签名字符串：\n%@\n\n",contentString];
    
    return md5Sign;
}
#pragma mark ---  将字符串进行MD5加密，返回加密后的字符串
-(NSString *) md5:(NSString *)str
{
    const char *cStr = [str UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)strlen(cStr), digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02X", digest[i]];
    
    return output;
}
/**
 订单号---我们是测试demo所以要生成随机的
正式项目不是
 @return
 */
-(NSString *)timeStamp{
    return [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
}
#pragma mark ---  获取IP
-(NSString *)getIP:(BOOL)preferIPv4{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    //NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
    return nil;
}
- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) || (interface->ifa_flags & IFF_LOOPBACK)) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                char addrBuf[INET6_ADDRSTRLEN];
                if(inet_ntop(addr->sin_family, &addr->sin_addr, addrBuf, sizeof(addrBuf))) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, addr->sin_family == AF_INET ? IP_ADDR_IPv4 : IP_ADDR_IPv6];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    //     The dictionary keys have the form "interface" "/" "ipv4 or ipv6"
    
    return [addresses count] ? addresses : nil;
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
