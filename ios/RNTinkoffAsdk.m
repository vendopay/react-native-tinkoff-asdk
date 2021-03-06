
#import "RNTinkoffAsdk.h"

#import <ASDKCore/ASDKCore.h>
#import <ASDKUI/ASDKUI.h>
#import "ASDKCardIOScanner.h"

#if __has_include("RCTConvert.h")
#import "RCTConvert.h"
#else
#import <React/RCTConvert.h>
#endif

@implementation RNTinkoffAsdk

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

ASDKAcquiringSdk *acquiringSdk;

RCT_EXPORT_METHOD(init:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  NSError* error = nil;

  if (![options objectForKey:@"terminalKey"]) {
      reject(@"init_error", @"Не передан terminalKey", error);
  }
  if (![options objectForKey:@"password"]) {
      reject(@"init_error", @"Не передан password", error);
  }
  if (![options objectForKey:@"publicKey"]) {
      reject(@"init_error", @"Не передан publicKey", error);
  }

  NSString *terminalKey = [RCTConvert NSString:options[@"terminalKey"]];
  NSString *password = [RCTConvert NSString:options[@"password"]];
  NSString *publicKey = [RCTConvert NSString:options[@"publicKey"]];

	ASDKStringKeyCreator *stringKeyCreator = [[ASDKStringKeyCreator alloc] initWithPublicKeyString:publicKey];

	acquiringSdk = [ASDKAcquiringSdk acquiringSdkWithTerminalKey:terminalKey
                                 payType:nil
																 password:password
															   publicKeyDataSource:stringKeyCreator];

  bool isTestMode = false;
  if (![options objectForKey:@"testMode"]) {
    isTestMode = [RCTConvert BOOL:options[@"testMode"]];
  }
  if (isTestMode) {
    NSLog(@"init tinkoff test mode");
    [acquiringSdk setDebug:YES];
    [acquiringSdk setTestDomain:YES];
  } else {
    NSLog(@"init tinkoff prod mode");
    //[acquiringSdk setDebug:NO];
    //[acquiringSdk setTestDomain:NO];
  }
  //[acquiringSdk setLogger:nil];
}

RCT_EXPORT_METHOD(isPayWithAppleAvailable:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    if ([ASDKPaymentFormStarter isPayWithAppleAvailable]) {
        resolve(@TRUE);
    } else {
        resolve(@FALSE);
    }
}

RCT_EXPORT_METHOD(Pay:(NSDictionary*) options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSError* error = nil;

    if (acquiringSdk == nil) {
        reject(@"init_not_done", @"Не выполнен init", error);
        return;
    };

    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;

    NSLog(@"%@",acquiringSdk);
    ASDKPaymentFormStarter * form = [ASDKPaymentFormStarter paymentFormStarterWithAcquiringSdk:acquiringSdk];

    form.cardScanner = [ASDKCardIOScanner scanner];

    NSNumber *amountCents = [options objectForKey:@"Amount"];
    double amountRub = (amountCents.doubleValue / 100);
    NSNumber *amount = @(amountRub);

    NSArray *items = [options objectForKey:@"Items"];

    NSDictionary *receiptData = @{
                                  @"Email": [options objectForKey:@"Email"],
                                  @"Phone": [options objectForKey:@"Phone"],
                                  @"Taxation": [options objectForKey:@"Taxation"],
                                  @"Items": items};
    NSDictionary *additionalPaymentData = @{
                                  @"Email": [options objectForKey:@"Email"],
                                  @"Phone": [options objectForKey:@"Phone"]};

    //NSLog(@"%@",receiptData);
    //NSLog(@"%@",additionalPaymentData);

    [form presentPaymentFormFromViewController:rootViewController
      orderId: [options objectForKey:@"OrderID"]
      amount: amount
      title: [options objectForKey:@"PaymentName"]
      description: [options objectForKey:@"PaymentDesc"]
      cardId: [options objectForKey:@"CardID"]
      email: [options objectForKey:@"Email"]
      customerKey: [options objectForKey:@"CustomerKey"]
      recurrent: NO
      makeCharge: YES
      additionalPaymentData: additionalPaymentData
      receiptData: receiptData
      //receiptData:nil
      //success:^(NSNumber *paymentId) { NSLog(@"%@",paymentId); resolve(paymentId); }
      success: ^(ASDKPaymentInfo *paymentInfo) { NSLog(@"%@",paymentInfo); resolve(paymentInfo); }
      cancelled: ^{ NSLog(@"cancelled"); reject(@"payment_cancelled", @"Платеж отменен", error); }
      error: ^(ASDKAcquringSdkError *error) {
          NSLog(@"%@",error);
          reject([NSString stringWithFormat:@"%ld", [error code]], [error errorMessage], error); }
    ];
}

RCT_EXPORT_METHOD(ApplePay:(NSDictionary*) options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSError* error = nil;

    if (acquiringSdk == nil) {
        reject(@"init_not_done", @"Не выполнен init", error);
        return;
    };

    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;

    ASDKPaymentFormStarter * form = [ASDKPaymentFormStarter paymentFormStarterWithAcquiringSdk:acquiringSdk];

    NSDictionary *shipping = [options objectForKey:@"Shipping"];

		PKContact *shippingContact = [[PKContact alloc] init];
		shippingContact.emailAddress = [options objectForKey:@"Email"];
		shippingContact.phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:[options objectForKey:@"Phone"]];
		CNMutablePostalAddress *postalAddress = [[CNMutablePostalAddress alloc] init];
		[postalAddress setStreet:[shipping objectForKey:@"Street"]];
		[postalAddress setCountry:[shipping objectForKey:@"Country"]];
		[postalAddress setCity:[shipping objectForKey:@"City"]];
		[postalAddress setPostalCode:[shipping objectForKey:@"PostalCode"]];
		[postalAddress setISOCountryCode:[shipping objectForKey:@"ISOCountryCode"]];
		shippingContact.postalAddress = [postalAddress copy];

    NSNumber *amountCents = [options objectForKey:@"Amount"];
    double amountRub = (amountCents.doubleValue / 100);
    NSNumber *amount = @(amountRub);

    NSDictionary *receiptData = @{
      @"Email": [options objectForKey:@"Email"],
      @"Phone": [options objectForKey:@"Phone"],
      @"Taxation": [options objectForKey:@"Taxation"],
      @"Items": [options objectForKey:@"Items"]};

    [form payWithApplePayFromViewController:rootViewController
      amount: amount
      orderId: [options objectForKey:@"OrderID"]
      description: [options objectForKey:@"PaymentDesc"]
      customerKey: [options objectForKey:@"customerKey"]
      sendEmail: YES
      email: [options objectForKey:@"email"]
      appleMerchantId: [options objectForKey:@"appleMerchantId"]
      shippingMethods:nil
      shippingContact:shippingContact
      shippingEditableFields:PKAddressFieldPostalAddress|PKAddressFieldName|PKAddressFieldEmail|PKAddressFieldPhone //PKAddressFieldNone
      recurrent: NO
      additionalPaymentData: [options objectForKey:@"extraData"]
      receiptData: receiptData
      shopsData:nil
      shopsReceiptsData:nil
      success: ^(ASDKPaymentInfo *paymentInfo) { NSLog(@"%@",paymentInfo); resolve(paymentInfo); }
      cancelled: ^{ reject(@"payment_cancelled", @"Платеж отменен", error); }
      error: ^(ASDKAcquringSdkError *error) { NSLog(@"%@",error); reject([NSString stringWithFormat:@"%ld", [error code]], [error errorMessage], error); }
    ];
}

@end
