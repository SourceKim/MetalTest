////  MetalUtils.h
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/3.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalUtils : NSObject

+ (nullable id<MTLTexture>)loadImageTexture: (UIImage *)image
                                     device: (id<MTLDevice>)device;

+ (nullable id<MTLTexture>)loadImageTexture_CGImage: (CGImageRef)cgImage
                                             device: (id<MTLDevice>)device;

@end

NS_ASSUME_NONNULL_END
