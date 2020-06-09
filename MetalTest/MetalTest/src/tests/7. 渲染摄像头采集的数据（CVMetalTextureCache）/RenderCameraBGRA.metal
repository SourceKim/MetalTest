////  RenderCameraBGRA.metal
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
RenderCameraBGRAVertexShader(
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
RenderCameraBGRAFragmentShader(
                               VertexOut in [[ stage_in ]],
                               texture2d<float, access::sample> tex [[ texture(0) ]]
                               ) {
    float4 color = tex.sample(texSampler, in.texCoor);
    return color;
}
