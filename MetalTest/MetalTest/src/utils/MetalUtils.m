////  MetalUtils.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/3.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "MetalUtils.h"

@implementation MetalUtils

+ (nullable id<MTLTexture>)createEmptyTexture: (id<MTLDevice>)device
                                    WithWidth: (size_t)width
                                   withHeight: (size_t)height
                                        usage: (MTLTextureUsage)usage {
    
    MTLTextureDescriptor *texDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: width height: height mipmapped: false];
    texDescriptor.usage = usage;
    
    id<MTLTexture> texture = [device newTextureWithDescriptor: texDescriptor];
    
    return texture;
}

+ (nullable id<MTLTexture>)loadImageTexture: (UIImage *)image
                                     device: (id<MTLDevice>)device
                                      usage: (MTLTextureUsage)usage {
    
    CGImageRef cgImage = image.CGImage;
    if (cgImage == nil) return nil;
    return [self loadImageTexture_CGImage: cgImage
                                   device: device
                                    usage: usage];
}

+ (nullable id<MTLTexture>)loadImageTexture_CGImage: (CGImageRef)cgImage
                                             device: (id<MTLDevice>)device
                                              usage: (MTLTextureUsage)usage {
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    CGRect rect = CGRectMake(0, 0, width, height);
    
    size_t dataLen = width * height * 4 * sizeof(uint8_t);
    uint8_t *imageData = malloc(dataLen);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(imageData,
                                             width,
                                             height,
                                             8,
                                             width * 4,
                                             colorSpace,
                                             kCGImageByteOrderDefault |
                                             kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(ctx, 0, height); // 所有内容下移 height
    CGContextScaleCTM(ctx, 1.0f, -1.0f); // 翻转
    CGContextClearRect(ctx, rect);
    CGContextDrawImage(ctx, rect, cgImage);
    
    id<MTLTexture> texture = [MetalUtils createEmptyTexture: device
                                                  WithWidth: width
                                                 withHeight: height
                                                      usage: usage];
    
    if (texture == nil) return nil;
    
    [texture replaceRegion: MTLRegionMake2D(0, 0, width, height) mipmapLevel: 0 withBytes: imageData bytesPerRow: width * 4];
    
    free(imageData);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(ctx);
    
    return texture;
    
}

@end
