//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<cunning_document_scanner/CunningDocumentScannerPlugin.h>)
#import <cunning_document_scanner/CunningDocumentScannerPlugin.h>
#else
@import cunning_document_scanner;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [CunningDocumentScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"CunningDocumentScannerPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
}

@end
