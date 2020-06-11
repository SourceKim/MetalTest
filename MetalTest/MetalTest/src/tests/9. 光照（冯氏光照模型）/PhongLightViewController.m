////  PhongLightViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/10.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "PhongLightViewController.h"

#import "MetalUtils.h"

#import "MetalMatrix.h"

static const float vertices[] = {
    
    // 正面
    -1, 1, 1,// 0
    1, 1, 1, // 1
    -1, -1, 1, // 3
    
    1, 1, 1, // 1
    1, -1, 1, // 2
    -1, -1, 1, // 3
    
    // 右面
    1, 1, 1, // 1
    1, -1, 1, // 2
    1, -1, -1, // 6
    
    1, 1, 1, // 1
    1, 1, -1, // 5
    1, -1, -1, // 6
    
    // 背面
    -1, 1, -1, // 4
    1, 1, -1, // 5
    -1, -1, -1, // 7
    
    1, 1, -1, // 5
    1, -1, -1, // 6
    -1, -1, -1, // 7
    
    // 左面
    -1, -1, 1, // 3
    -1, 1, -1, // 4
    -1, -1, -1, // 7
    
    -1, 1, 1,// 0
    -1, -1, 1, // 3
    -1, 1, -1, // 4
    
    // 上面
    -1, 1, 1,// 0
    1, 1, 1, // 1
    -1, 1, -1, // 4
   
    1, 1, 1, // 1
    -1, 1, -1, // 4
    1, 1, -1, // 5
    
    // 下面
    1, -1, 1, // 2
    -1, -1, 1, // 3
    1, -1, -1, // 6
    
    -1, -1, 1, // 3
    1, -1, -1, // 6
    -1, -1, -1, // 7
};

static const float normals[] = {
    
    // 正面
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    
    // 右面
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,
    
    // 背面
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    
    // 左面
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,
    
    // 上面
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    0, 1, 0,
    
    // 下面
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
    0, -1, 0,
};

@interface PhongLightViewController ()

@end

@implementation PhongLightViewController {
    
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_renderTargetDesc;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLTexture> _depthTexture;
    
    id<MTLDepthStencilState> _depthStencilState;
    
    id<MTLBuffer> _indexBuffer;
    
    simd_float4x4 _objModelMatrix, _cameraModelMatrix, _viewMatrix, _projectionMatrix;
    
    CADisplayLink *_dis;
    float _cameraDistance;
    
    
    simd_float3 _objColor, _cameraColor;
    simd_float3 _lightPos, _eyePos;
    float _ambientStrength, _specularStrength;
    
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cameraDistance = 10;
    
    _dis = [CADisplayLink displayLinkWithTarget: self selector: @selector(rotateCube)];
    
    _objColor = simd_make_float3(1, 0, 0);
    _cameraColor = simd_make_float3(1, 1, 1);
    
    _lightPos = simd_make_float3(3, 3, 3);
    _eyePos = simd_make_float3(0, 0, -_cameraDistance);
    
    _ambientStrength = 0.2;
    _specularStrength = 0.5;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipeline];
    [self setupDepthStencilTexuture];
    [self setupDepthStencil];
    
    _objModelMatrix = [MetalMatrix mm_identity];
    
    simd_float4x4 cameraTranslate = [MetalMatrix mm_translate: _lightPos];
    simd_float4x4 cameraScale = [MetalMatrix mm_scaleWithX: 0.5 withY: 0.5 withZ: 0.5];
    _cameraModelMatrix = simd_mul(cameraTranslate, cameraScale);
    
    _viewMatrix = [MetalMatrix mm_lookAtWithEyeX: _eyePos.x
                                        withEyeY: _eyePos.y
                                        withEyeZ: _eyePos.z
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

#pragma mark - Rotate Cube

- (void)rotateCube {
    double time = [[NSDate date] timeIntervalSince1970];
    float angle = sin(time * 0.3);
    _objModelMatrix = [MetalMatrix mm_rotate: angle * 360 withX: 1 withY: 1 withZ: 1];
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
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"PhongLightVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"PhongLightFragmentShader"];
    
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

- (void)render {
    
    id<CAMetalDrawable> currentDrawable = [_layer nextDrawable];
    _renderTargetDesc.colorAttachments[0].texture = currentDrawable.texture;
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    commandBuffer.label = @"Command Buffer";
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor: _renderTargetDesc];
    encoder.label = @"Object Render Command Encoder";
    
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
    
    [self render_obj: encoder]; // 渲染旋转的物体
    
    [self render_camera: encoder]; // 渲染光源
    
    [encoder endEncoding];
    
    [commandBuffer presentDrawable: currentDrawable];
    
    [commandBuffer commit];
}

- (void)render_obj: (id<MTLRenderCommandEncoder>)encoder{
    
    bool needLight = true;
    
    [encoder pushDebugGroup: @"Obj Draw Call"];
    
    [encoder setVertexBytes: vertices
                     length: sizeof(vertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: normals
                     length: sizeof(normals)
                    atIndex: 1];
    
    [encoder setVertexBytes: &_objModelMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 2];
    
    [encoder setVertexBytes: &_viewMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 3];
    
    [encoder setVertexBytes: &_projectionMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 4];
    
    [encoder setFragmentBytes: &_objColor length: sizeof(simd_float3) atIndex: 0];
    [encoder setFragmentBytes: &needLight length: sizeof(bool) atIndex: 1];
    [encoder setFragmentBytes: &_cameraColor length: sizeof(simd_float3) atIndex: 2];
    [encoder setFragmentBytes: &_ambientStrength length: sizeof(float) atIndex: 3];
    [encoder setFragmentBytes: &_lightPos length: sizeof(simd_float3) atIndex: 4];
    [encoder setFragmentBytes: &_eyePos length: sizeof(simd_float3) atIndex: 5];
    [encoder setFragmentBytes: &_specularStrength length: sizeof(float) atIndex: 6];
    
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 36];
    
    [encoder popDebugGroup];
}

- (void)render_camera: (id<MTLRenderCommandEncoder>)encoder {
    
    bool needLight = false;
    
    [encoder pushDebugGroup: @"Camera Draw Call"];
    
    [encoder setVertexBytes: vertices
                     length: sizeof(vertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: normals
                     length: sizeof(normals)
                    atIndex: 1];
    
    [encoder setVertexBytes: &_cameraModelMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 2];
    
    [encoder setVertexBytes: &_viewMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 3];
    
    [encoder setVertexBytes: &_projectionMatrix
                     length: [MetalMatrix mm_matrixSize]
                    atIndex: 4];
    
    [encoder setFragmentBytes: &_cameraColor length: sizeof(simd_float3) atIndex: 0];
    [encoder setFragmentBytes: &needLight length: sizeof(bool) atIndex: 1];
    
    [encoder drawPrimitives: MTLPrimitiveTypeTriangle
                vertexStart: 0
                vertexCount: 36];
    
    [encoder popDebugGroup];
}

@end
