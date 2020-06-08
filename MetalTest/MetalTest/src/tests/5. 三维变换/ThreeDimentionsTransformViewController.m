////  ThreeDimentionsTransformViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/8.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "ThreeDimentionsTransformViewController.h"

#import "MetalUtils.h"

#import "MetalMatrix.h"

static const float vertices[] = {
    -0.5, -0.5, 0, 1, // 左下角
    0.5, -0.5, 0, 1, // 右下角
    -0.5, 0.5, 0, 1, // 左上角
    0.5, 0.5, 0, 1, // 右上角
};

static const float texCoor[] = {
    0, 0, // 左下角
    1, 0, // 右下角
    0, 1, // 左上角
    1, 1, // 右上角
};

static const UInt32 indices[] = {
    0, 1, 2,
    1, 3, 2
};

@interface ThreeDimentionsTransformViewController ()

@end

@implementation ThreeDimentionsTransformViewController {
    
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_renderTargetDesc;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLTexture> _texutre;
    
    id<MTLBuffer> _indexBuffer;
    
    simd_float4x4 _modelMatrix, _viewMatrix, _projectionMatrix;
    
    CADisplayLink *_dis;
    float _cameraDistance;
    int _cameraDegree;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(rotateCamera)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipeline];
    [self loadTexture];
    [self setupIndexBuffer];
    
    _modelMatrix = [MetalMatrix mm_identity];
    
    _cameraDistance = 2;
    
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
    
    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
}

#pragma mark - Rotate Camera

- (void)rotateCamera {
    
    float x = _cameraDistance * sin(MM_RADIANS(_cameraDegree));
    float z = _cameraDistance * cos(MM_RADIANS(_cameraDegree));
    
    _viewMatrix = [MetalMatrix mm_lookAtWithEyeX: x
                                        withEyeY: 0
                                        withEyeZ: -z
                                     withCenterX: 0
                                     withCenterY: 0
                                     withCenterZ: 0
                                         withUpX: 0
                                         withUpY: 1
                                         withUpZ: 0];
    [self render];
    
    if (_cameraDegree == 360) {
        _cameraDegree = 0;
    } else {
        _cameraDegree += 3;
    }
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
}

- (void)setupRenderPipeline {
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"ThreeDimentionTransformVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"ThreeDimentionTransformFragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;
    
    NSError *err;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    
    NSAssert(_renderPipelineState != nil, @"Failed to create pipeline state: %@", err);
}

- (void)loadTexture {
    UIImage *image = [UIImage imageNamed: @"avatar.JPG"];
    _texutre = [MetalUtils loadImageTexture: image device: _device usage: MTLTextureUsageShaderRead];
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
    
    [encoder setVertexBytes: vertices
                     length: sizeof(vertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: texCoor
                     length: sizeof(texCoor)
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
    
    [encoder setFragmentTexture: _texutre
                        atIndex: 0];
    
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangleStrip
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
    
    [encoder endEncoding];
    
    [commandBuffer presentDrawable: currentDrawable];
    
    [commandBuffer commit];
}

@end
