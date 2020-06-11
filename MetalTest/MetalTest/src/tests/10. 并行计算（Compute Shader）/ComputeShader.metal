////  ComputeShader.metal
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/11.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

float2 mappedToMinus3To3(uint2 position, uint2 size) {
    
}

bool isTopPartOfHeart(float2 mappedPosition) {
    return true;
}

kernel
void ComputeKernelShader(device uint *outBuffer [[ buffer(0) ]],
                         constant uint2 &outSize [[ buffer(1) ]],
                         uint2 position [[ thread_position_in_grid ]]) {
    
    if (position.x > outSize.x || position.y > outSize.y) {
        return;
    }
    
    outBuffer[0] = 128;
}
