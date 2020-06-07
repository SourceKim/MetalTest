//
//  MetalMatrix.m
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/8.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "MetalMatrix.h"

#define kRADIANS (1.0f / 180.0f * M_PI)
#define RADIANS(degrees) degrees * kRADIANS
#define RADIANS_OVER_PI(degrees) degrees * (1.f / 180.f)

@implementation MetalMatrix

#pragma mark Public - Transformations - Scale

+ (simd_float4x4)mm_scale: (simd_float3)vector {
    
    simd_float4 v = simd_make_float4(vector, 1);
    
    return simd_diagonal_matrix(v);
}

+ (simd_float4x4)mm_scaleWithX: (float)x
                         withY: (float)y
                         withZ: (float)z {
    
    simd_float3 v = simd_make_float3(x, y, z);
    
    return [self mm_scale: v];
}

#pragma mark Public - Transformations - Translate

+ (simd_float4x4)mm_translate: (simd_float3)vector {
    
    simd_float4x4 M = matrix_identity_float4x4;
    
    M.columns[3].xyz = vector;
    return M;
}

+ (simd_float4x4)mm_translateWithX: (float)x
                             withY: (float)y
                             withZ: (float)z {
    
    simd_float3 v = simd_make_float3(x, y, z);
    
    return [self mm_translate: v];
}

#pragma mark Public - Transformations - Rotate

+ (simd_float4x4)mm_rotate: (float)angle
                      axis: (simd_float3)axis {
    
    float a = RADIANS_OVER_PI(angle);
    float c = 0.0f;
    float s = 0.0f;
    
    // Computes the sine and cosine of pi times angle (measured in radians)
    // faster and gives exact results for angle = 90, 180, 270, etc.
    __sincospif(a, &s, &c);
    
    float k = 1.0f - c;
    
    simd_float3 u = simd_normalize(axis);
    simd_float3 v = s * u;
    simd_float3 w = k * u;
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = w.x * u.x + c;
    P.y = w.x * u.y + v.z;
    P.z = w.x * u.z - v.y;
    P.w = 0.0f;
    
    Q.x = w.x * u.y - v.z;
    Q.y = w.y * u.y + c;
    Q.z = w.y * u.z + v.x;
    Q.w = 0.0f;
    
    R.x = w.x * u.z + v.y;
    R.y = w.y * u.z - v.x;
    R.z = w.z * u.z + c;
    R.w = 0.0f;
    
    S.x = 0.0f;
    S.y = 0.0f;
    S.z = 0.0f;
    S.w = 1.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_rotate: (float)angle
                     withX: (float)x
                     withY: (float)y
                     withZ: (float)z {
    
    simd_float3 v = simd_make_float3(x, y, z);
    
    return [self mm_rotate: angle axis: v];
}

#pragma mark Public - Transformations - Perspective

+ (simd_float4x4)mm_perspectiveWithWidth: (float)width
                              withHeight: (float)height
                                withNear: (float)near
                                 withFar: (float)far {
    
    float zNear = 2.0f * near;
    float zFar  = far / (far - near);
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = zNear / width;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = zNear / height;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = zFar;
    R.w = 1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -near * zFar;
    S.w =  0.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_perspectiveWithFovy: (float)fovy
                             withAspect: (float)aspect
                               withNear: (float)near
                                withFar: (float)far {
    
    float angle  = RADIANS(0.5 * fovy);
    float yScale = 1.0f / tanf(angle);
    float xScale = yScale / aspect;
    float zScale = far / (far - near);
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = xScale;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = yScale;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = zScale;
    R.w = 1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -near * zScale;
    S.w =  0.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_perspectiveWithFovy: (float)fovy
                              withWidth: (float)width
                             withHeight: (float)height
                               withNear: (float)near
                                withFar: (float)far {
    
    float aspect = width / height;
    
    return [self mm_perspectiveWithFovy: fovy
                             withAspect: aspect
                               withNear: near
                                withFar: far];
}

#pragma mark Public - Transformations - LookAt

+ (simd_float4x4)mm_lookAtWithEye: (simd_float3)eye
                       withCenter: (simd_float3)center
                           withUp: (simd_float3)up {
    
    
    simd_float3 zAxis = simd_normalize(center - eye);
    simd_float3 xAxis = simd_normalize(simd_cross(up, zAxis));
    simd_float3 yAxis = simd_cross(zAxis, xAxis);
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = xAxis.x;
    P.y = yAxis.x;
    P.z = zAxis.x;
    P.w = 0.0f;
    
    Q.x = xAxis.y;
    Q.y = yAxis.y;
    Q.z = zAxis.y;
    Q.w = 0.0f;
    
    R.x = xAxis.z;
    R.y = yAxis.z;
    R.z = zAxis.z;
    R.w = 0.0f;
    
    S.x = -simd_dot(xAxis, eye);
    S.y = -simd_dot(yAxis, eye);
    S.z = -simd_dot(zAxis, eye);
    S.w =  1.0f;
    
    return simd_matrix(P, Q, R, S);
}

#pragma mark Public - Transformations - Orthographic

+ (simd_float4x4)mm_orthoWithLeft: (float)left
                        withRight: (float)right
                       withBottom: (float)bottom
                          withTop: (float)top
                         withNear: (float)near
                          withFar: (float)far {
    
    float sLength = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = 1.0f / (far   - near);
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = 2.0f * sLength;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = 2.0f * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 0.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -near  * sDepth;
    S.w =  1.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_orthoWithOrigin: (simd_float3)origin
                           withSize: (simd_float3)size {
    
    return [self mm_orthoWithLeft: origin.x
                        withRight: origin.y
                       withBottom: origin.z
                          withTop: size.x
                         withNear: size.y
                          withFar: size.z];
}

#pragma mark Public - Transformations - Off-Center Orthographic

+ (simd_float4x4)mm_ortho_ocWithLeft: (float)left
                           withRight: (float)right
                          withBottom: (float)bottom
                             withTop: (float)top
                            withNear: (float)near
                             withFar: (float)far {
    
    float sLength = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = 1.0f / (far   - near);
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = 2.0f * sLength;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = 2.0f * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 0.0f;
    
    S.x = -sLength * (left + right);
    S.y = -sHeight * (top + bottom);
    S.z = -sDepth  * near;
    S.w =  1.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_ortho_ocWithOrigin: (simd_float3)origin
                              withSize: (simd_float3)size {
    
    return [self mm_ortho_ocWithLeft: origin.x
                           withRight: origin.y
                          withBottom: origin.z
                             withTop: size.x
                            withNear: size.y
                             withFar: size.z];
}

#pragma mark Public - Transformations - frustum

+ (simd_float4x4)mm_frustumWithFovH: (float)fovH
                           withFovV: (float)fovV
                           withNear: (float)near
                            withFar: (float)far {
    
    float width = 1.0f / tanf(RADIANS(0.5f * fovH));
    float height = 1.0f / tanf(RADIANS(0.5f * fovV));
    float sDepth = far / ( far - near );
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = width;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = height;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -sDepth * near;
    S.w =  0.0f;
    
    return simd_matrix(P, Q, R, S);
}

+ (simd_float4x4)mm_frustumWithLeft: (float)left
                          withRight: (float)right
                         withBotoom: (float)bottom
                            withTop: (float)top
                           withNear: (float)near
                            withFar: (float)far {
    
    float width  = right - left;
    float height = top   - bottom;
    float depth  = far   - near;
    float sDepth = far / depth;
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = width;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = height;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = 0.0f;
    R.y = 0.0f;
    R.z = sDepth;
    R.w = 1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -sDepth * near;
    S.w =  0.0f;
    
    return simd_matrix(P, Q, R, S);
}

#pragma mark Public - Transformations - Off-Center frustum

+ (simd_float4x4)mm_frustum_ocWithLeft: (float)left
                             withRight: (float)right
                            withBotoom: (float)bottom
                               withTop: (float)top
                              withNear: (float)near
                               withFar: (float)far {
    
    float sWidth  = 1.0f / (right - left);
    float sHeight = 1.0f / (top   - bottom);
    float sDepth  = far  / (far   - near);
    float dNear   = 2.0f * near;
    
    simd_float4 P;
    simd_float4 Q;
    simd_float4 R;
    simd_float4 S;
    
    P.x = dNear * sWidth;
    P.y = 0.0f;
    P.z = 0.0f;
    P.w = 0.0f;
    
    Q.x = 0.0f;
    Q.y = dNear * sHeight;
    Q.z = 0.0f;
    Q.w = 0.0f;
    
    R.x = -sWidth  * (right + left);
    R.y = -sHeight * (top   + bottom);
    R.z =  sDepth;
    R.w =  1.0f;
    
    S.x =  0.0f;
    S.y =  0.0f;
    S.z = -sDepth * near;
    S.w =  0.0f;
    
    return simd_matrix(P, Q, R, S);
}

@end
