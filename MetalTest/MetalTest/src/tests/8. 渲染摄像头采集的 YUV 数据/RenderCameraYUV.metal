////  RenderCameraYUV.metal
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/9.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constexpr sampler texSampler;

typedef struct
{
    float4 position [[position]];
    float2 texCoor;
    
} VertexOut;

vertex VertexOut
RenderCameraYUVVertexShader(
                            uint vertexID [[ vertex_id ]],
                            constant float4 *position [[ buffer(0) ]],
                            constant float2 *texCoor [[ buffer(1) ]]
                            ) {
    VertexOut out;
    
    out.position = position[vertexID];
    out.texCoor = texCoor[vertexID];
    
    return out;
}

fragment float4
RenderCameraYUVFragmentShader(
                              VertexOut in [[ stage_in ]],
                              texture2d<float, access::sample> lumaTex [[ texture(0) ]],
                              texture2d<float, access::sample> chromaTex [[ texture(1) ]],
                              constant float3x3 *YUV_To_RGB_Matrix [[ buffer(0) ]],
                              constant float3 *YUV_Translation [[ buffer(1) ]]
                              ) {
    float3 yuv, rgb;
    
    yuv.r = lumaTex.sample(texSampler, in.texCoor).r;
    yuv.gb = chromaTex.sample(texSampler, in.texCoor).rg;
    
    rgb = YUV_To_RGB_Matrix[0] * (yuv + YUV_Translation[0]);
    
    return float4(rgb, 1);
}
