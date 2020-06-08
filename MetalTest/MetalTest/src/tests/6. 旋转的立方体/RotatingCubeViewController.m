////  RotatingCubeViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/8.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RotatingCubeViewController.h"

#import "MetalUtils.h"

#import "MetalMatrix.h"

static const float vertices[] = {
    -1, 1, 1, 1, // 0
    1, 1, 1, 1, // 1
    1, -1, 1, 1, // 2
    -1, -1, 1, 1, // 3
    -1, 1, -1, 1, // 4
    1, 1, -1, 1, // 5
    1, -1, -1, 1, // 6
    -1, -1, -1, 1 // 7
};

static const float vertexColor[] = {
    1, 0, 0, 1, // 0
    1, 1, 0, 1, // 1
    1, 1, 1, 1, // 2
    1, 0, 1, 1, // 3
    0, 1, 0, 1, // 4
    0, 1, 1, 1, // 5
    0, 0, 1, 1, // 6
    0, 0, 0, 1, // 7
};

static const UInt32 indices[] = {
    // 正面
    0, 1, 3,
    1, 2, 3,
    
    // 右面
    1, 2, 6,
    1, 5, 6,
    
    // 背面
    4, 5, 7,
    5, 6, 7,
    
    // 左面
    3, 4, 7,
    0, 3, 4,
    
    // 上面
    0, 1, 4,
    1, 4, 5,
    
    // 下面
    2, 3, 6,
    3, 6, 7,
};


@interface RotatingCubeViewController ()

@end

@implementation RotatingCubeViewController {
    
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_renderTargetDesc;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLTexture> _depthTexture;
    
    id<MTLDepthStencilState> _depthStencilState;
    
    id<MTLBuffer> _indexBuffer;
    
    simd_float4x4 _modelMatrix, _viewMatrix, _projectionMatrix;
    
    CADisplayLink *_dis;
    float _cameraDistance;
    int _cameraDegree;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cameraDistance = 10;
    
    _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(rotateCube)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipeline];
    [self setupDepthStencilTexuture];
    [self setupDepthStencil];
    [self setupIndexBuffer];
    
    _modelMatrix = [MetalMatrix mm_identity];
    
    _viewMatrix = [MetalMatrix mm_lookAtWithEyeX: 0
                                        withEyeY: 0
                                        withEyeZ: -_cameraDistance
                                     withCenterX: 0
                                     withCenterY: 0
                                     withCenterZ: 0
                                         withUpX: 0
                                         withUpY: 1
                                         withUpZ: 0];
    
    _projectionMatrix = [MetalMatrix mm_perspectiveWithFovy: 90
                                                  withWidth: CGRectGetWidth(_layer.bounds)
                                                 withHeight: CGRectGetHeight(_layer.bounds)
                                                   withNear: 0.1
                                                    withFar: 100];
    
//    [self render];
    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
}

#pragma mark - Rotate Cube

- (void)rotateCube {
    double time = [[NSDate date] timeIntervalSince1970];
    float angle = sin(time);
    _modelMatrix = [MetalMatrix mm_rotate: angle * 360 withX: 1 withY: 1 withZ: 1];
    [self render];
}

#pragma mark - Metal

- (void)setupMetal {
    
    _device = MTLCreateSystemDefaultDevice();
    
    _queue = [_device newCommandQueue];
}

- (void)setupLayer {
    
    _layer = [CAMetalLayer layer];
    _layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _layer.framebufferOnly = true;
    _layer.frame = self.view.bounds;
    
    CGFloat scale = self.view.contentScaleFactor;
    _layer.drawableSize = CGSizeApplyAffineTransform(self.view.bounds.size, CGAffineTransformMakeScale(scale, scale));
    
    [self.view.layer insertSublayer: _layer atIndex: 0];
}

- (void)setupRenderTarget {
    
    _renderTargetDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    MTLRenderPassColorAttachmentDescriptor *colorAttachment = _renderTargetDesc.colorAttachments[0];
//    colorAttachment.texture = [_layer nextDrawable].texture;
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.storeAction = MTLStoreActionStore;
    colorAttachment.clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    _renderTargetDesc.depthAttachment.clearDepth = 1;
}

- (void)setupRenderPipeline {
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"RotatingCubeVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"RotatingCubeFragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;
    
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float; // depth format
    
    NSError *err;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    
    NSAssert(_renderPipelineState != nil, @"Failed to create pipeline state: %@", err);
}

- (void)setupDepthStencilTexuture {
    
    _depthTexture = [MetalUtils createDepthStencilTexture: _device
                                                WithWidth: _layer.drawableSize.width
                                               withHeight: _layer.drawableSize.height];
    
    _renderTargetDesc.depthAttachment.texture = _depthTexture;
}

- (void)setupDepthStencil {
    MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
    depthStencilDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDesc.depthWriteEnabled = true;
    _depthStencilState = [_device newDepthStencilStateWithDescriptor: depthStencilDesc];
}

- (void)setupIndexBuffer {
    
    _indexBuffer = [_device newBufferWithBytes: indices
                                        length: sizeof(indices)
                                       options: MTLResourceStorageModeShared];
}

- (void)render {
    
    id<CAMetalDrawable> currentDrawable = [_layer nextDrawable];
    _renderTargetDesc.colorAttachments[0].texture = currentDrawable.texture;
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    commandBuffer.label = @"Command Buffer";
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderTargetDesc];
    encoder.label = @"Render Command Encoder";
    
    [encoder setViewport: (MTLViewport) {
        .originX = 0,
        .originY = 0,
        .width = _layer.drawableSize.width,
        .height = _layer.drawableSize.height,
        .znear = 0,
        .zfar = 1
    }];
    
    [encoder setRenderPipelineState: _renderPipelineState];
    
    // depth
    [encoder setDepthStencilState: _depthStencilState];
    
    [encoder setVertexBytes: vertices
                     length: sizeof(vertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: vertexColor
                     length: sizeof(vertexColor)
                    atIndex: 1];
    
    [encoder setVertexBytes: &_modelMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 2];
    
    [encoder setVertexBytes: &_viewMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 3];
    
    [encoder setVertexBytes: &_projectionMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 4];
    
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle // Triangle
                        indexCount: sizeof(indices) / sizeof(UInt32)
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
    
    [encoder endEncoding];
    
    [commandBuffer presentDrawable: currentDrawable];
    
    [commandBuffer commit];
}

@end
