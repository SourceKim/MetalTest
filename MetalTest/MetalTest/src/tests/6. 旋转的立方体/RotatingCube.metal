////  RotatingCube.metal
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
    float4 vertexColor;
    
} VertexOut;

vertex VertexOut
RotatingCubeVertexShader(
                         uint vertexID [[ vertex_id ]],
                         constant float4 *position [[ buffer(0) ]],
                         constant float4 *vertexColor [[ buffer(1) ]],
                         constant float4x4 *modelMatrix [[ buffer(2) ]],
                         constant float4x4 *viewMatrix [[ buffer(3) ]],
                         constant float4x4 *projectionMatrix [[ buffer(4) ]]
                         ) {
    VertexOut out;
    
    out.position = projectionMatrix[0] * viewMatrix[0] * modelMatrix[0] * position[vertexID];
    out.vertexColor = vertexColor[vertexID];
    
    return out;
}

fragment float4
RotatingCubeFragmentShader(
                           VertexOut in [[ stage_in ]]
                           ) {
    return in.vertexColor;
}
