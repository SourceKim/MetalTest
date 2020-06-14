//
//  BlendingViewController.m
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/14.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "BlendingViewController.h"

#import "MetalUtils.h"

// 左上顶点
static const float vertices0[] = {
    -1, -0.25, 0, // 左下角
    0.25, -0.25, 0, // 右下角
    -1, 1, 0, // 左上角
    0.25, 1, 0 // 右上角
};

// 右下顶点
static const float vertices1[] = {
    -0.25, -1, 0, // 左下角
    1, -1, 0, // 右下角
    -0.25, 0.25, 0, // 左上角
    1, 0.25, 0 // 右上角
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

@interface BlendingViewController ()

@end

@implementation BlendingViewController {
    
    UIImage *_redImage, *_greenImage;
    
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_renderTargetDesc;
    
    id<MTLRenderPipelineState> _renderPipelineState0, _renderPipelineState1;
    
    id<MTLTexture> _texture0, _texture1;
    
    id<MTLBuffer> _indexBuffer;
}

#pragma mark - Life Circle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    _redImage = [self createPureColorImage: UIColor.redColor alpha: 1]; // 红色不透明
    _greenImage = [self createPureColorImage: UIColor.greenColor alpha: 0.5]; // 绿色是半透明的
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipelines];
    [self loadTextures];
    [self setupIndexBuffer];
    
    [self render];
//    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
}

#pragma mark - Create pure color images

- (UIImage *)createPureColorImage: (UIColor *)color
                            alpha: (CGFloat)alpha {
    
    UIColor *colorWithAlpha = [color colorWithAlphaComponent: alpha];
    
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [colorWithAlpha CGColor]);
    CGContextFillRect(context, rect);
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return theImage;
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

- (void)setupRenderPipelines {
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"BlendingVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"BlendingFragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;
    
    // Red image pipeline state
    NSError *err;
    _renderPipelineState0 = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    
    NSAssert(_renderPipelineState0 != nil, @"Failed to create pipeline state: %@", err);
    
    // Green image pipeline state
    
    // 1. setup color & alpha factor
    pipelineDescriptor.colorAttachments[0].blendingEnabled = true;
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    // 2. Use new descriptor to generate green pipeline state
    _renderPipelineState1 = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    
    NSAssert(_renderPipelineState1 != nil, @"Failed to create pipeline state: %@", err);
}

- (void)loadTextures {
    _texture0 = [MetalUtils loadImageTexture: _redImage device: _device usage: MTLTextureUsageShaderRead];
    _texture1 = [MetalUtils loadImageTexture: _greenImage device: _device usage: MTLTextureUsageShaderRead];
}

- (void)setupIndexBuffer {
    
    _indexBuffer = [_device newBufferWithBytes: indices
                                        length: sizeof(indices)
                                       options: MTLResourceStorageModeShared];
}

- (void)render_red: (id<MTLRenderCommandEncoder>)encoder {
    
    [encoder setRenderPipelineState: _renderPipelineState0];
    
    [encoder setVertexBytes: vertices0
                     length: sizeof(vertices0)
                    atIndex: 0];
    
    [encoder setVertexBytes: texCoor
                     length: sizeof(texCoor)
                    atIndex: 1];
    
    [encoder setFragmentTexture: _texture0
                        atIndex: 0];
    
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
}

- (void)render_green: (id<MTLRenderCommandEncoder>)encoder {
    
    [encoder setRenderPipelineState: _renderPipelineState1];
    
    [encoder setVertexBytes: vertices1
                     length: sizeof(vertices1)
                    atIndex: 0];
    
    [encoder setVertexBytes: texCoor
                     length: sizeof(texCoor)
                    atIndex: 1];
    
    [encoder setFragmentTexture: _texture1
                        atIndex: 0];
    
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangle
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
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
    
    [self render_red: encoder];
    
    [self render_green: encoder];
    
    [encoder endEncoding];
    
    [commandBuffer presentDrawable: currentDrawable];
    
    [commandBuffer commit];
}


@end
