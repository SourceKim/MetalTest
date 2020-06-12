////  ComputeShaderViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/11.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "ComputeShaderViewController.h"

#import "MetalUtils.h"

#import <simd/simd.h>

@interface ComputeShaderViewController ()

@end

@implementation ComputeShaderViewController {
    
    NSUInteger _outW, _outH;
    
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    id<MTLComputePipelineState> _computePipelineState;
    
    MTLSize _threadgroupsPerGrid; // 每个计算网格的 线程组 size
    MTLSize _threadsPerThreadGroup; // 每个线程组的 线程 size
    
    id<MTLBuffer> _outputBuffer;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    _outW = 1024;
    _outH = 1024;
    
    [self setupMetal];
    [self setupComputePipeline];
    [self createOutputBuffer];
    [self setupThreadGroups: _outW totalHeight: _outH];
    [self compute];
    
    for (NSUInteger y = 0; y < 3; y++) {
        for (NSUInteger x = 0; x < 3; x++) {
            [self showBufferContentWithX: x withY: y];
        }
    }
}

#pragma mark - Result Verifying

- (void)showBufferContentWithX: (NSUInteger)x
                         withY: (NSUInteger)y {
    
    uint32_t *res = _outputBuffer.contents;
    
    uint32_t resOfIdx = res[y * _outW + x];
    NSLog(@"The result of (%d, %d) is - %d", (int)x, (int)y, resOfIdx);
}

#pragma mark - Metal

- (void)setupMetal {
    
    _device = MTLCreateSystemDefaultDevice();
    
    _queue = [_device newCommandQueue];
}

- (void)setupComputePipeline {
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> kernelFunc = [library newFunctionWithName: @"ComputeKernelShader"];
    
    NSError *err;
    _computePipelineState = [_device newComputePipelineStateWithFunction: kernelFunc error: &err];
    
    NSAssert(_computePipelineState != nil, @"Failed to create pipeline state: %@", err);
}

- (void)createOutputBuffer {
    
    _outputBuffer = [_device newBufferWithLength: _outW * _outH * sizeof(uint32_t)
                                         options: MTLResourceStorageModeShared];
}

- (void)setupThreadGroups: (NSUInteger)totalWidth totalHeight: (NSUInteger)totalHeight {
    
    // Refer apple doc
    // https://developer.apple.com/documentation/metal/calculating_threadgroup_and_grid_sizes?language=objc
    
    NSUInteger w = _computePipelineState.threadExecutionWidth; // 最有效率的线程执行宽度
    NSUInteger h = _computePipelineState.maxTotalThreadsPerThreadgroup / w; // 每个线程组最多的线程数量
    
    _threadsPerThreadGroup = MTLSizeMake(w,
                                         h,
                                         1);
    
    _threadgroupsPerGrid = MTLSizeMake((totalWidth + w - 1) / w,
                                       (totalHeight + h - 1) / h,
                                       1);
}

- (void)compute {
    
    simd_uint2 outSize = simd_make_uint2((uint32_t)_outW, (uint32_t)_outH);
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    [encoder setComputePipelineState: _computePipelineState];
    
    [encoder setBuffer: _outputBuffer offset: 0 atIndex: 0];
    
    [encoder setBytes: &outSize length: sizeof(simd_uint2) atIndex: 1];
    
    [encoder dispatchThreadgroups: _threadgroupsPerGrid threadsPerThreadgroup: _threadsPerThreadGroup];
    
    [encoder endEncoding]; 
    
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cmd) {
        NSLog(@"Finish Computing.");
    }];
    
    [commandBuffer commit];
    
    [commandBuffer waitUntilCompleted];
}

@end
