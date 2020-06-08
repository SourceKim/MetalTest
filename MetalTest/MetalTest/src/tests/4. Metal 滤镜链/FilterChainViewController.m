//
//  FilterChainViewController.m
//  MetalTest
//
//  Created by 苏金劲 on 2020/6/4.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "FilterChainViewController.h"

#import "MetalUtils.h"

static const float grayVertices[] = {
    -1, 1, 0, 1, // 左上角
    1, 1, 0, 1, // 右上角
    -1, -1, 0, 1, // 左下角
    1, -1, 0, 1, // 右下角
};

static const float brightnessVertices[] = {
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

@interface FilterChainViewController ()

@property (weak, nonatomic) IBOutlet UIView *renderView;

@end

@implementation FilterChainViewController {
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_grayRenderTargetDesc;
    MTLRenderPassDescriptor *_BrightnessRenderTargetDesc;
    
    id<MTLRenderPipelineState> _grayRenderPipelineState;
    id<MTLRenderPipelineState> _brightnessRenderPipelineState;
    
    id<MTLTexture> _sourceTexutre;
    id<MTLTexture> _grayResultTexutre;
    
    id<MTLBuffer> _indexBuffer;
    
    float _grayIntensity, _brightness;
}

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _grayIntensity = 0;
    _brightness = 0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipeline];
    [self loadTexture];
    [self setupIndexBuffer];
    
    [self render];
//    [_dis addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
}

#pragma mark - Response

- (IBAction)onGraySliderChanged:(id)sender {
    _grayIntensity = ((UISlider *)sender).value;
    [self render];
}

- (IBAction)onBrightnessSliderChanged:(id)sender {
    _brightness = ((UISlider *)sender).value;
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
    _layer.frame = self.renderView.bounds;
    
    CGFloat scale = self.renderView.contentScaleFactor;
    _layer.drawableSize = CGSizeApplyAffineTransform(self.renderView.bounds.size, CGAffineTransformMakeScale(scale, scale));
    
    [self.renderView.layer insertSublayer: _layer atIndex: 0];
}

- (void)setupRenderTarget {
    
    _grayRenderTargetDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    MTLRenderPassColorAttachmentDescriptor *colorAttachment = _grayRenderTargetDesc.colorAttachments[0];
//    colorAttachment.texture = [_layer nextDrawable].texture;
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.storeAction = MTLStoreActionStore;
    colorAttachment.clearColor = MTLClearColorMake(0, 0, 0, 1);
    
    _BrightnessRenderTargetDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    colorAttachment = _BrightnessRenderTargetDesc.colorAttachments[0];
    //    colorAttachment.texture = [_layer nextDrawable].texture;
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.storeAction = MTLStoreActionStore;
    colorAttachment.clearColor = MTLClearColorMake(1, 1, 1, 1);
}

- (void)setupRenderPipeline {
    
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"filterChainVertexShader"];
    id<MTLFunction> grayfragmentFunc = [library newFunctionWithName: @"grayFilterFragmentShader"];
    id<MTLFunction> brightnessfragmentFunc = [library newFunctionWithName: @"brightnessFilterFragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    NSError *err;
    
    // Gray pipeline desc
    pipelineDescriptor.label = @"Gray Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = grayfragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    
    _grayRenderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    NSAssert(_grayRenderPipelineState != nil, @"Failed to create pipeline state: %@", err);
    
    // Brightness pipeline desc
    pipelineDescriptor.label = @"Brightness Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = brightnessfragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;
    
    _brightnessRenderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    NSAssert(_grayRenderPipelineState != nil, @"Failed to create pipeline state: %@", err);
}

- (void)loadTexture {
    UIImage *image = [UIImage imageNamed: @"avatar.JPG"];
    _sourceTexutre = [MetalUtils loadImageTexture: image
                                           device: _device
                                            usage: MTLTextureUsageShaderRead];
    
    CGImageRef cgImage = image.CGImage;
    _grayResultTexutre = [MetalUtils createEmptyTexture: _device
                                              WithWidth: CGImageGetWidth(cgImage)
                                             withHeight: CGImageGetHeight(cgImage)
                                                  usage: MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget];
}

- (void)setupIndexBuffer {
    
    _indexBuffer = [_device newBufferWithBytes: indices
                                        length: sizeof(indices)
                                       options: MTLResourceStorageModeShared];
}

- (void)render_gray {
    
    // 将本次 Command Encoder 和 渲染的目标（MTLTexture）关联起来
    _grayRenderTargetDesc.colorAttachments[0].texture = _grayResultTexutre;
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    commandBuffer.label = @"Gray Command Buffer";
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor: _grayRenderTargetDesc];
    encoder.label = @"Gray Command Encoder";
    
    [encoder setViewport: (MTLViewport) {
        .originX = 0,
        .originY = 0,
        .width = _sourceTexutre.width,
        .height = _sourceTexutre.height,
        .znear = 0,
        .zfar = 1
    }];
    
    [encoder setRenderPipelineState: _grayRenderPipelineState];
    
    [encoder setVertexBytes: grayVertices
                     length: sizeof(grayVertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: texCoor
                     length: sizeof(texCoor)
                    atIndex: 1];
    
    [encoder setFragmentTexture: _sourceTexutre
                        atIndex: 0];
    
    [encoder setFragmentBytes: &_grayIntensity
                       length: sizeof(float)
                      atIndex: 0];
    
    [encoder drawIndexedPrimitives: MTLPrimitiveTypeTriangleStrip
                        indexCount: 6
                         indexType: MTLIndexTypeUInt32
                       indexBuffer: _indexBuffer
                 indexBufferOffset: 0];
    
    [encoder endEncoding];
    
    [commandBuffer commit];
}

- (void)render_brightness {
    
    id<CAMetalDrawable> currentDrawable = [_layer nextDrawable];
    
    // 将本次 Command Encoder 和 渲染的目标（Layer 的 texture）关联起来
    _BrightnessRenderTargetDesc.colorAttachments[0].texture = currentDrawable.texture;
    
    id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
    commandBuffer.label = @"Brightness Command Buffer";
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor: _BrightnessRenderTargetDesc];
    encoder.label = @"Brightness Command Encoder";
    
    [encoder setViewport: (MTLViewport) {
        .originX = 0,
        .originY = 0,
        .width = _layer.drawableSize.width,
        .height = _layer.drawableSize.height,
        .znear = 0,
        .zfar = 1
    }];
    
    [encoder setRenderPipelineState: _brightnessRenderPipelineState];
    
    [encoder setVertexBytes: brightnessVertices
                     length: sizeof(brightnessVertices)
                    atIndex: 0];
    
    [encoder setVertexBytes: texCoor
                     length: sizeof(texCoor)
                    atIndex: 1];
    
    [encoder setFragmentTexture: _grayResultTexutre
                        atIndex: 0];
    
    [encoder setFragmentBytes: &_brightness
                       length: sizeof(float)
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

- (void)render {
    /*
        1. 先进行灰度的渲染（输入是原图（sourceImage），输出是空白的 MTLTexture）
     
        2. 将第一步输出的 MTLTexture 作为 Brightness 的输入，输出到 Layer 的 texture
     
     */
    [self render_gray];
    [self render_brightness];
}

@end
