////  ThreeDimentionsTransform.metal
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/8.
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
ThreeDimentionTransformVertexShader(
                                    uint vertexID [[ vertex_id ]],
                                    constant float4 *position [[ buffer(0) ]],
                                    constant float2 *texCoor [[ buffer(1) ]],
                                    constant float4x4 *modelMatrix [[ buffer(2) ]],
                                    constant float4x4 *viewMatrix [[ buffer(3) ]],
                                    constant float4x4 *projectionMatrix [[ buffer(4) ]]
                                    ) {
    VertexOut out;
    
    out.position = projectionMatrix[0] * viewMatrix[0] * modelMatrix[0] * position[vertexID];
    out.texCoor = texCoor[vertexID];
    
    return out;
}

fragment float4
ThreeDimentionTransformFragmentShader(
                                      VertexOut in [[ stage_in ]],
                                      texture2d<float, access::sample> tex [[ texture(0) ]]
                                      ) {
    constexpr sampler texSampler;
    float4 color = tex.sample(texSampler, in.texCoor);
    return color;
}
