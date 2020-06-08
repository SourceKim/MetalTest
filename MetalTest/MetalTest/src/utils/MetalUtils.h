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

/*
 Texture Create & Load
 
 Note: The default texture pixel-format is RGBA8UNorm
 */

+ (nullable id<MTLTexture>)createEmptyTexture: (id<MTLDevice>)device
                                    WithWidth: (size_t)width
                                   withHeight: (size_t)height
                                        usage: (MTLTextureUsage)usage;

+ (nullable id<MTLTexture>)loadImageTexture: (UIImage *)image
                                     device: (id<MTLDevice>)device
                                      usage: (MTLTextureUsage)usage;

+ (nullable id<MTLTexture>)loadImageTexture_CGImage: (CGImageRef)cgImage
                                             device: (id<MTLDevice>)device
                                              usage: (MTLTextureUsage)usage;

+ (nullable id<MTLTexture>)createDepthStencilTexture: (id<MTLDevice>)device
                                           WithWidth: (size_t)width
                                          withHeight: (size_t)height;

@end

NS_ASSUME_NONNULL_END
