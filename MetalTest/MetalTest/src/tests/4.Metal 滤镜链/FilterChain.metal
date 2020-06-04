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
