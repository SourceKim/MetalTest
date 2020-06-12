////  ComputeShader.metal
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/11.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel
void ComputeKernelShader(device uint *outBuffer [[ buffer(0) ]],
                         constant uint2 &outSize [[ buffer(1) ]],
                         uint2 position [[ thread_position_in_grid ]]) {
    
    if (position.x >= outSize.x || position.y >= outSize.y) {
        return;
    }
    
    uint idx = position.y * outSize.x + position.x;
    outBuffer[idx] = idx;
}
