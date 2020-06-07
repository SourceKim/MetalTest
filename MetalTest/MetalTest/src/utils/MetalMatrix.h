//
//  MetalMatrix.h
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/8.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetalMatrix : NSObject

#pragma mark Public - Transformations - Scale

+ (simd_float4x4)mm_scale: (simd_float3)vector;

+ (simd_float4x4)mm_scaleWithX: (float)x
                         withY: (float)y
                         withZ: (float)z;


#pragma mark Public - Transformations - Translate

+ (simd_float4x4)mm_translate: (simd_float3)vector;

+ (simd_float4x4)mm_translateWithX: (float)x
                             withY: (float)y
                             withZ: (float)z;


#pragma mark Public - Transformations - Rotate

+ (simd_float4x4)mm_rotate: (float)angle
                      axis: (simd_float3)axis;

+ (simd_float4x4)mm_rotate: (float)angle
                     withX: (float)x
                     withY: (float)y
                     withZ: (float)z;


#pragma mark Public - Transformations - Perspective

+ (simd_float4x4)mm_perspectiveWithWidth: (float)width
                              withHeight: (float)height
                                withNear: (float)near
                                 withFar: (float)far;

+ (simd_float4x4)mm_perspectiveWithFovy: (float)fovy
                             withAspect: (float)aspect
                               withNear: (float)near
                                withFar: (float)far;

+ (simd_float4x4)mm_perspectiveWithFovy: (float)fovy
                              withWidth: (float)width
                             withHeight: (float)height
                               withNear: (float)near
                                withFar: (float)far;


#pragma mark Public - Transformations - LookAt

+ (simd_float4x4)mm_lookAtWithEye: (simd_float3)eye
                       withCenter: (simd_float3)center
                           withUp: (simd_float3)up;


#pragma mark Public - Transformations - Orthographic

+ (simd_float4x4)mm_orthoWithLeft: (float)left
                        withRight: (float)right
                       withBottom: (float)bottom
                          withTop: (float)top
                         withNear: (float)near
                          withFar: (float)far;

+ (simd_float4x4)mm_orthoWithOrigin: (simd_float3)origin
                           withSize: (simd_float3)size;


#pragma mark Public - Transformations - Off-Center Orthographic

+ (simd_float4x4)mm_ortho_ocWithLeft: (float)left
                           withRight: (float)right
                          withBottom: (float)bottom
                             withTop: (float)top
                            withNear: (float)near
                             withFar: (float)far;

+ (simd_float4x4)mm_ortho_ocWithOrigin: (simd_float3)origin
                              withSize: (simd_float3)size;


#pragma mark Public - Transformations - frustum

+ (simd_float4x4)mm_frustumWithFovH: (float)fovH
                           withFovV: (float)fovV
                           withNear: (float)near
                            withFar: (float)far;

+ (simd_float4x4)mm_frustumWithLeft: (float)left
                          withRight: (float)right
                         withBotoom: (float)bottom
                            withTop: (float)top
                           withNear: (float)near
                            withFar: (float)far;


#pragma mark Public - Transformations - Off-Center frustum

+ (simd_float4x4)mm_frustum_ocWithLeft: (float)left
                             withRight: (float)right
                            withBotoom: (float)bottom
                               withTop: (float)top
                              withNear: (float)near
                               withFar: (float)far;
@end

NS_ASSUME_NONNULL_END
