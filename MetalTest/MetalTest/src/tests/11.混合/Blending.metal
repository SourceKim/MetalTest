//
//  Blending.metal
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/14.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texCoor;
    
} VertexOut;

vertex VertexOut
BlendingVertexShader(
                     uint vertexID [[ vertex_id ]],
                     constant packed_float3 *position [[ buffer(0) ]],
                     constant packed_float2 *texCoor [[ buffer(1) ]]
                     ) {
    VertexOut out;
    
    out.position = float4(position[vertexID], 1);
    out.texCoor = texCoor[vertexID];
    
    return out;
}

fragment float4
BlendingFragmentShader(
                       VertexOut in [[ stage_in ]],
                       texture2d<float, access::sample> tex [[ texture(0) ]]
                       ) {
    constexpr sampler texSampler;
    float4 color = tex.sample(texSampler, in.texCoor);
    return color;
}
