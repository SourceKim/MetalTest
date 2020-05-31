//
//  Triangle.metal
//  MetalTest
//
//  Created by 苏金劲 on 2020/5/31.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    // The [[position]] attribute of this member indicates that this value
    // is the clip space position of the vertex when this structure is
    // returned from the vertex function.
    float4 position [[position]];

    // Since this member does not have a special attribute, the rasterizer
    // interpolates its value with the values of the other triangle vertices
    // and then passes the interpolated value to the fragment shader for each
    // fragment in the triangle.
    float4 color;

} VertexOut;

vertex VertexOut
vertexShader(uint vertexID [[ vertex_id ]],
             constant float4 *position [[ buffer(0) ]],
             constant float4 *color [[ buffer(1) ]]
             )
{
    VertexOut out;
    
    out.position = position[vertexID];
    out.color = color[vertexID];
    
    return out;
}

fragment float4
fragmentShader(VertexOut fragmentIn [[ stage_in ]])
{
    return fragmentIn.color;
}
