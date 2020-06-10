////  RenderCameraYUVViewController.m
//  MetalTest
//
//  Created by Su Jinjin on 2020/6/9.
//  Copyright © 2020 苏金劲. All rights reserved.
//

#import "RenderCameraYUVViewController.h"

#import "MetalUtils.h"

#import <AVFoundation/AVFoundation.h>

#import "YUV_To_RGB_Matrices_Vectors.h"

#import <simd/simd.h>

static const float vertices[] = {
    -1, -1, 0, 1, // 左下角
    1, -1, 0, 1, // 右下角
    -1, 1, 0, 1, // 左上角
    1, 1, 0, 1, // 右上角
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

@interface RenderCameraYUVViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RenderCameraYUVViewController {
    
    bool _useFullRangeYUV;
    
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
    
    id<MTLTexture> _lumaTexutre, _chromaTexture;
    
    id<MTLBuffer> _indexBuffer;
    
    simd_float3x3 _YUV_To_RGB_Matrix;
    
    simd_float3 _YUV_Tranlation;
}

#pragma mark - Life Circle

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    _useFullRangeYUV = true;
    
    // 配置摄像头，采集 YUV 数据
    if (_useFullRangeYUV) {
        [self setupCamera: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    } else {
        [self setupCamera: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    }
    
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

#pragma mark - 更新 YUV 转 RGB 的 Tramsform Matrix 和 Translation Vector

- (void)updateMatrixAndVector:(CVImageBufferRef)imageBuffer
                  isFullRange:(bool)isFullRange {
    
    CFTypeRef matrixType = CVBufferGetAttachment(imageBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    bool use601;
    
    if (matrixType != NULL) {
        use601 = CFStringCompare(matrixType, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo;
    } else {
        use601 = true;
    }
    
    if (use601) {
        _YUV_To_RGB_Matrix = isFullRange ? kColorConversion601FullRange_simd : kColorConversion601_simd;
    } else {
        _YUV_To_RGB_Matrix = kColorConversion709_simd;
    }
    
    _YUV_Tranlation = isFullRange ? kColorTranslationFullRange_simd : kColorTranslationVideoRange_simd;
}

#pragma mark - 采集的 Pixel Buffer 转换成 Metal 的 Texture

- (CVMetalTextureRef)acquireTextureFromBuffer: (CVPixelBufferRef)buffer isLuma: (bool)isLuma {
    
    MTLPixelFormat format = isLuma ? MTLPixelFormatR8Unorm : MTLPixelFormatRG8Unorm; // 1 channel : 2 channel
    size_t planeIndex = isLuma ? 0 : 1; // 选择某一个平面
    
    CVMetalTextureRef texture;
    CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                             _textureCache,
                                                             buffer,
                                                             NULL,
                                                             format,
                                                             CVPixelBufferGetWidthOfPlane(buffer, planeIndex), // Get width of plane
                                                             CVPixelBufferGetHeightOfPlane(buffer, planeIndex), // Get Height of plane
                                                             planeIndex,
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
    _session.sessionPreset = AVCaptureSessionPresetHigh;
    
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
    
    // 因为 Metal 的纹理 Y 轴和 UIKit 的是相反的，所以这里采集需要上下颠倒
    connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    [connection setVideoMirrored: true];
    
    [_session commitConfiguration];
    return true;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    // Metal 是线程安全的，其他线程的返回没有关系
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    [self updateMatrixAndVector: imageBuffer isFullRange: _useFullRangeYUV]; // 更新 Matrix & Vector
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    CVMetalTextureRef lumaTexture = [self acquireTextureFromBuffer: imageBuffer isLuma: true]; // PixelBuffer => CV Metal Texture
    CVMetalTextureRef chromaTexture = [self acquireTextureFromBuffer: imageBuffer isLuma: false]; // PixelBuffer => CV Metal Texture
    _lumaTexutre = CVMetalTextureGetTexture(lumaTexture); // CV Metal Texture -> MTLTexture
    _chromaTexture = CVMetalTextureGetTexture(chromaTexture); // CV Metal Texture -> MTLTexture
    
    [self render]; // 执行渲染
    
    CVMetalTextureCacheFlush(_textureCache, 0); // 渲染完毕之后清空一下 texture cache
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    if (lumaTexture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(lumaTexture); // 没有这个，就会不再采集！！！！
    }
    if (chromaTexture != NULL) { // 如果 texture 为 NULL，再 Release 就会出现 `EXC_BREAKPOINT` crash！
        CFRelease(chromaTexture); // 没有这个，就会不再采集！！！！
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
    
    id<MTLFunction> vertexFunc = [library newFunctionWithName: @"RenderCameraYUVVertexShader"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName: @"RenderCameraYUVFragmentShader"];
    
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
    
    [encoder setFragmentTexture: _lumaTexutre
                        atIndex: 0];
    
    [encoder setFragmentTexture: _chromaTexture
                        atIndex: 1];
    
    [encoder setFragmentBytes: &_YUV_To_RGB_Matrix length: sizeof(simd_float3x3) atIndex: 0];
    
    [encoder setFragmentBytes: &_YUV_Tranlation length: sizeof(simd_float3) atIndex: 1];
    
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
