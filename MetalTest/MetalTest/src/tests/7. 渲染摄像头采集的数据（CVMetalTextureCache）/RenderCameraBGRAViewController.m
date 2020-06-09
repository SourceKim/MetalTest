////  RenderCameraBGRAViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/9.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RenderCameraBGRAViewController.h"

#import "MetalUtils.h"

#import <AVFoundation/AVFoundation.h>

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

@interface RenderCameraBGRAViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RenderCameraBGRAViewController {
    
    // AVFoundation
    AVCaptureSession *_session;
    dispatch_queue_t _captureQueue;
    
    // [Core Graphics - Metal] Texture Cache
    CVMetalTextureCacheRef _textureCache;
    
    // Metal
    id<MTLDevice> _device;
    
    id<MTLCommandQueue> _queue;
    
    CAMetalLayer *_layer;
    
    MTLRenderPassDescriptor *_renderTargetDesc;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLTexture> _texutre;
    
    id<MTLBuffer> _indexBuffer;
}

#pragma mark - Life Circle

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    [self setupCamera: kCVPixelFormatType_32BGRA];
    
    [self setupMetal];
    [self setupLayer];
    [self setupRenderTarget];
    [self setupRenderPipeline];
    [self setupIndexBuffer];
    [self setupTextureCache];
    
    [AVCaptureDevice requestAccessForMediaType: AVMediaTypeVideo
                             completionHandler:^(BOOL granted) {
        if (granted) {
            [self->_session startRunning];
        }
    }];
}

#pragma mark - 采集的 Pixel Buffer 转换成 Metal 的 Texture

- (CVMetalTextureRef)acquireTextureFromBuffer: (CVPixelBufferRef)buffer {
    
    CVMetalTextureRef texture;
    CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                             _textureCache,
                                                             buffer,
                                                             NULL,
                                                             MTLPixelFormatBGRA8Unorm,
                                                             CVPixelBufferGetWidth(buffer),
                                                             CVPixelBufferGetHeight(buffer),
                                                             0,
                                                             &texture);
    
    if (ret != kCVReturnSuccess) {
        NSLog(@"Read texture faild from sample buffer, %d", ret);
    }
    
    return texture;
}

#pragma mark - Camera

- (bool)setupCamera: (OSType)pixelFormatType {
    
    _session = [[AVCaptureSession alloc] init];
    _captureQueue = dispatch_queue_create(0, 0);
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType: AVMediaTypeVideo];
    device = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                mediaType: AVMediaTypeVideo
                                                 position: AVCaptureDevicePositionBack];
    
    if (device == nil) {
        return false;
    }
    
    NSError *err;
    AVCaptureInput *input = [[AVCaptureDeviceInput alloc] initWithDevice: device error: &err];
    
    if (input == nil || err != nil) {
        return false;
    }
    
    [_session beginConfiguration];
    _session.sessionPreset = AVCaptureSessionPreset640x480;
    
    if (![_session canAddInput: input]) {
        [_session commitConfiguration];
        return false;
    }
    [_session addInput: input];
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.videoSettings = @{ (NSString *)kCVPixelBufferPixelFormatTypeKey: @(pixelFormatType) };
    [output setAlwaysDiscardsLateVideoFrames: true];
    [output setSampleBufferDelegate: self queue: _captureQueue];
    
    if (![_session canAddOutput: output]) {
        [_session commitConfiguration];
        return false;
    }
    [_session addOutput: output];
    
    AVCaptureConnection *connection = [output connectionWithMediaType: AVMediaTypeVideo];
    
    if (connection == nil) {
        [_session commitConfiguration];
        return false;
    }
    
    // 因为 OpenGL 的纹理 Y 轴和 UIKit 的是相反的，所以这里采集需要上下颠倒
    connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
//    [connection setVideoMirrored: true];
    
    [_session commitConfiguration];
    return true;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    // Metal 是线程安全的，其他线程的返回没有关系
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    CVMetalTextureRef texture = [self acquireTextureFromBuffer: imageBuffer]; // PixelBuffer => CV Metal Texture
    _texutre = CVMetalTextureGetTexture(texture); // CV Metal Texture -> MTLTexture
    
    [self render];
    
    CVMetalTextureCacheFlush(_textureCache, 0); // 渲染完毕之后清空一下 texture cache
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if (texture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(texture); // 没有这个，就会不再采集！！！！
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
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"RenderCameraBGRAVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"RenderCameraBGRAFragmentShader"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"Render Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _layer.pixelFormat;
    
    NSError *err;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor: pipelineDescriptor error: &err];
    
    NSAssert(_renderPipelineState != nil, @"Failed to create pipeline state: %@", err);
}

- (void)setupIndexBuffer {
    
    _indexBuffer = [_device newBufferWithBytes: indices
                                        length: sizeof(indices)
                                       options: MTLResourceStorageModeShared];
}

- (void)setupTextureCache {
    
    CVReturn ret = CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);
    
    if (ret != kCVReturnSuccess) {
        NSLog(@"Create cache failed");
    }
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
