//
//  ETDecoder.m
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import "ETDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#include <CoreVideo/CoreVideo.h>

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

@interface ETDecoder ()
{
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    
    CVPixelBufferRef _currentPixelBuffer;
    
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
}

@property (nonatomic, strong) NSThread *decoderThread;
@property (nonatomic, strong) NSMutableArray *videoFrameBufferArray;
@property (nonatomic, strong) ETVideoPacket *startVideoPacket;
@property (nonatomic, assign) NSInteger frameRate;
@property (nonatomic, assign) BOOL showDisplayView;
@property (nonatomic, assign) BOOL endData;

@property (nonatomic, strong) NSLock *bufferLock;
@property (nonatomic, strong) NSLock *showOpenglLock;
@end

@implementation ETDecoder

- (NSLock *)showOpenglLock {
    if (!_showOpenglLock) {
        _showOpenglLock = [[NSLock alloc] init];
    }
    return _showOpenglLock;
}

- (NSLock *)bufferLock {
    if (!_bufferLock) {
        _bufferLock = [[NSLock alloc] init];
    }
    
    return _bufferLock;
}

- (NSMutableArray *)videoFrameBufferArray {
    if (!_videoFrameBufferArray) {
        _videoFrameBufferArray = [NSMutableArray array];
    }
    
    return _videoFrameBufferArray;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.frameRate = 60;
        self.showDisplayView = YES;
    }
    
    return self;
}

- (instancetype)initWithShowVideoView:(UIView*)showView {
    self = [super init];
    
    if (self) {
        self.frameRate = 60;
        self.showDisplayView = YES;
    }
    
    return self;
}

#pragma mark -- 设置是否绘图
- (void)setDisplayViewShowEnable:(BOOL)pShowDisplayView {
    [self.showOpenglLock lock];
    self.showDisplayView = pShowDisplayView;
    [self.showOpenglLock unlock];
}

#pragma mark -- 开始播放
- (void) startDecode {
    self.decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(decoderThreadMethod) object:nil];
    [self.decoderThread start];
}

#pragma mark -- 设置播放帧率
- (void)setFrameRate:(NSInteger)frameRate {
    _frameRate = frameRate;
}

#pragma mark -- 添加数据到播放队列
- (void) sendFrameDataToDecodeQueue:(uint8_t *)frameBuffer length:(NSInteger)length
//- (void) sendFrameDataToDecodeQueue:(NSData *)frameBuffer length:(NSInteger)length
{
    [self.bufferLock lock];
    
    if (!self.startVideoPacket || 0 == self.startVideoPacket.size) {
        [self initStartVideoPacket:frameBuffer length:length];
    }
    
    NSArray *packetArray = [ETH264Parser packetVideoData:frameBuffer bufferLength:length];
    [self.videoFrameBufferArray addObjectsFromArray:packetArray];
    
    
    [self.bufferLock unlock];
}

#pragma mark -- 获取当前的图像
- (UIImage *)currentOpenglImage {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:_currentPixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(_currentPixelBuffer),
                                                 CVPixelBufferGetHeight(_currentPixelBuffer))];
    
    UIImage *image = [[UIImage alloc] initWithCGImage:videoImage];
    
    CGImageRelease(videoImage);

    return image;
}

#pragma mark -- 初始化第一段码流包
- (void) initStartVideoPacket:(uint8_t *)frameBuffer  length:(NSInteger)length {
    self.startVideoPacket = [[ETVideoPacket alloc] initWithSize:length];
    
//    memcpy(self.startVideoPacket.buffer, frameBuffer, length);
    self.startVideoPacket.bufferData = [NSData dataWithBytes:frameBuffer length:length];
    
}

- (void) clearStartVideoPacketBuffer {
    self.startVideoPacket = nil;
}

- (void) setEndDataState:(BOOL)isEnd {
    self.endData = isEnd;
}

- (void)updateOpenglSize {
    if (self.delegate && [self.delegate respondsToSelector:@selector(decoder:didGetPixelBuffer:)]) {
        [self.delegate decoder:self didGetPixelBuffer:_currentPixelBuffer];
    }
}

#pragma mark -- 解码线程
- (void) decoderThreadMethod {
    ETVideoPacket *framePacket = nil;

    while (TRUE && ![[NSThread currentThread] isCancelled]) {
        framePacket = [self nextFrameBuffer];
        if(nil == framePacket) {
            if (YES == self.endData) {
                [self stopDecode];
            }
            usleep(1000*1000/self.frameRate);
            continue;
        }

        uint32_t nalSize = (uint32_t)(framePacket.size - 4);
        uint8_t *pNalSize = (uint8_t*)(&nalSize);
        
        uint8_t *bytes = (uint8_t *)[framePacket.bufferData bytes];
        
        bytes[0] = *(pNalSize + 3);
        bytes[1] = *(pNalSize + 2);
        bytes[2] = *(pNalSize + 1);
        bytes[3] = *(pNalSize);
        
        CVPixelBufferRef pixelBuffer = NULL;
        int nalType = bytes[4] & 0x1F;
        switch (nalType) {
            case 0x05:
                if([self initH264Decoder])
                {
                    pixelBuffer = [self decode:framePacket];
                }
                break;
            case 0x07:
                if (_sps) {
                    free(_sps);
                }
                _spsSize = framePacket.size - 4;
                _sps = malloc(_spsSize);
                memcpy(_sps, bytes + 4, _spsSize);
                break;
            case 0x08:
                if (_pps) {
                    free(_pps);
                }
                _ppsSize = framePacket.size - 4;
                _pps = malloc(_ppsSize);
                memcpy(_pps, bytes + 4, _ppsSize);
                break;
                
            default:
                pixelBuffer = [self decode:framePacket];
                break;
        }
        
        if(pixelBuffer) {
            
            if (_currentPixelBuffer) {
                CVPixelBufferRelease(_currentPixelBuffer);
            }
            _currentPixelBuffer = CVPixelBufferRetain(pixelBuffer);

            [self.showOpenglLock lock];
            BOOL showEnable = self.showDisplayView;
            [self.showOpenglLock unlock];
            
            if (showEnable) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(decoder:didGetPixelBuffer:)]) {
                    [self.delegate decoder:self didGetPixelBuffer:pixelBuffer];
                    CVPixelBufferRelease(pixelBuffer);
                }
            }
            
        }
        usleep(1000*1000/self.frameRate);
    }
}

- (ETVideoPacket *)nextFrameBuffer {
    [self.bufferLock lock];
    ETVideoPacket *framePacket = nil;
    
    if (self.videoFrameBufferArray.count) {
        
        if (self.videoFrameBufferArray.count) {
            framePacket = [self.videoFrameBufferArray firstObject];
            [self.videoFrameBufferArray removeObjectAtIndex:0];
        }
    }
    
    [self.bufferLock unlock];
    
    return framePacket;//[ETH264Parser parseVideoPacket:framePacket];
}

- (ETVideoPacket *)nextFrameOriginBuffer {
    [self.bufferLock lock];
    ETVideoPacket *framePacket = nil;
    if (self.videoFrameBufferArray.count) {
        
        framePacket = [self.videoFrameBufferArray firstObject];

//        [self.videoFrameBufferArray removeObjectAtIndex:0];
    }
    [self.bufferLock unlock];
    
    return framePacket;//[ETH264Parser parseVideoPacket:framePacket];
}

#pragma mark -- 停止播放*/
- (void) stopDecode {
    [self.decoderThread cancel];
    
    self.videoFrameBufferArray = [NSMutableArray array];
}
//-(BOOL)initH264Decoder:(uint8_t*)spsBuffer spsLength:(size_t)length ppsBuffer:(uint8_t*)ppsBuffer ppsLenth:(size_t)ppsLenth
-(BOOL)initH264Decoder {
    if(_deocderSession) {
        return YES;
    }
    
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = NULL;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &_deocderSession);
        CFRelease(attrs);
    } else {
        ETLog(@"IOS8VT: reset decoder session failed status=%d", status);
        return NO;
    }
    
    return YES;
}

-(CVPixelBufferRef)decode:(ETVideoPacket*)vp {
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    if(!_deocderSession) {
        return NULL;
    }
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)[vp.bufferData bytes], vp.size,
                                                          kCFAllocatorNull,
                                                          NULL, 0, vp.size,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        
        if (NULL == blockBuffer) {
            ETLog(@"----------------------blockBuffer null");
        }
        const size_t sampleSizeArray[] = {vp.size};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            
            if (!_deocderSession) {
                ETLog(@"----------------------_deocderSession null");
            }
            
            if (NULL == sampleBuffer) {
                ETLog(@"----------------------sampleBuffer null");
            }
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
//                ETLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
//                ETLog(@"IOS8VT: decode failed status=%d(Bad data)", decodeStatus);
            } else if(decodeStatus != noErr) {
//                ETLog(@"IOS8VT: decode failed status=%d", decodeStatus);
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    else {
//        ETLog(@"status = %d", status);
    }

    return outputPixelBuffer;
}


-(void)clearH264Deocder {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    if (_sps) {
        free(_sps);
    }
    
    if (_pps) {
        free(_pps);
    }
    
    _spsSize = _ppsSize = 0;
}

- (void)dealloc
{
    if (_currentPixelBuffer) {
        CVPixelBufferRelease(_currentPixelBuffer);
    }
    [self clearH264Deocder];
}

@end
