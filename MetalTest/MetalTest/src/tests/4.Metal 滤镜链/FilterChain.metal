//
//  FilterChain.metal
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/4.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texCoor;

} VertexOut;

constexpr sampler texSampler(
                             address::clamp_to_edge,
                             filter::linear
                             );

constant const float3 LUMINANCE_FACTOR = float3(0.2125, 0.7154, 0.0721);

vertex VertexOut
filterChainVertexShader(
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
grayFilterFragmentShader(
                         VertexOut in [[ stage_in ]],
                         texture2d<float, access::sample> tex [[ texture(0) ]],
                         constant float *intensity [[ buffer(0) ]]
                         ) {
    float4 color = tex.sample(texSampler, in.texCoor);
    float luminance = dot(color.rgb, LUMINANCE_FACTOR);
    float3 mixColor = mix(float3(luminance), color.rgb, 1 - intensity[0]);
    return float4(mixColor, 1);
}

fragment float4
brightnessFilterFragmentShader(
                               VertexOut in [[ stage_in ]],
                               texture2d<float, access::sample> tex [[ texture(0) ]],
                               constant float *brightness [[ buffer(0) ]]
                               ) {
    float4 color = tex.sample(texSampler, in.texCoor);
    return float4(float3(color.rgb + brightness[0]), 1);
}
