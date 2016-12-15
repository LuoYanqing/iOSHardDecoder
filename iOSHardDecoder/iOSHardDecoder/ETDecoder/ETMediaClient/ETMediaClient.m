//
//  ETMediaClient.m
//  iOSHardDecoder
//
//  Created by EthanLuo on 16/12/15.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import "ETMediaClient.h"
#import "ETDecoder.h"

@interface ETMediaClient () <ETDecoderDelegate>
@property (nonatomic, strong) ETEAGLLayer *videoLayer;
@property (nonatomic, strong) ETDecoder *h264HardDecoder;

@property (nonatomic, assign) BOOL isUsePrivateView;
@end

@implementation ETMediaClient

#pragma mark -- init with private video view
- (instancetype)initWithFrame:(CGRect)videFrame {
    self = [super init];
    if (self) {
        self.endData = NO;
        self.videoView = [[UIView alloc] initWithFrame:videFrame];
        
        self.videoLayer = [[ETEAGLLayer alloc] initWithFrame:self.videoView.bounds];
        
        self.videoLayer.backgroundColor = [UIColor grayColor].CGColor;
        
        [self.videoView.layer insertSublayer:self.videoLayer atIndex:0];
        
        self.isUsePrivateView = YES;
    }
    
    return self;
}

#pragma mark -- init with user video view
- (instancetype)initWithSuperView:(UIView *)superView {
    self = [super init];
    if (self) {
        self.endData = NO;
        CGRect videFrame = superView.bounds;
        
        self.videoLayer = [[ETEAGLLayer alloc] initWithFrame:videFrame];
        self.videoLayer.backgroundColor = [UIColor grayColor].CGColor;
        
        [superView.layer insertSublayer:self.videoLayer atIndex:0];
        
        self.isUsePrivateView = NO;
    }
    
    return self;
}

- (void) startDecodeing {
    if (self.h264HardDecoder) {
        self.endData = NO;
        [self.h264HardDecoder startDecode];
    }
}

- (void)setFrameRate:(NSInteger)frameRate {
    if (self.h264HardDecoder) {
        [self.h264HardDecoder setFrameRate:frameRate];
    }
}

- (void) sendFrameDataToDecodeQueue:(uint8_t *)frameBuffer length:(NSInteger)length {
    if (self.h264HardDecoder) {
        [self.h264HardDecoder sendFrameDataToDecodeQueue:frameBuffer length:length];
    }
}

- (BOOL)capturePicture:(ETPictureType) picType path:(NSString *)path{
    BOOL success = NO;
    if (self.h264HardDecoder) {
        UIImage *videoImage =  [self.h264HardDecoder currentOpenglImage];
        
        if (videoImage) {
            if (ETPictureTypePNG == picType) {
                NSData *pngData = UIImagePNGRepresentation(videoImage);
                if (pngData) {
                    success = [pngData writeToFile:path atomically:YES];
                }
            }
            else {
                NSData *jpgData = UIImageJPEGRepresentation(videoImage, 1.0);
                if (jpgData) {
                    success = [jpgData writeToFile:path atomically:YES];
                }
            }
        }
    }
    
    return success;
}

- (void)setDisplayViewShowEnable:(BOOL)pShowDisplayView {
    if (self.h264HardDecoder) {
        [self.h264HardDecoder setDisplayViewShowEnable:pShowDisplayView];
    }
}

- (void) updateVideoFrame:(CGRect)frame {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (YES == self.isUsePrivateView) {
            self.videoView.frame = frame;
            self.videoLayer.frame = self.videoView.bounds;
        }
        else {
            CGRect videFrame = CGRectMake(0, 0, CGRectGetWidth(frame), CGRectGetHeight(frame));
            self.videoLayer.frame = videFrame;
        }
        if (self.h264HardDecoder) {
            [self.h264HardDecoder updateOpenglSize];
        }
    });
}

- (void) stopDecodeing {
    if (self.h264HardDecoder) {
        [self.h264HardDecoder stopDecode];
    }
}

#pragma mark -- ETDecoderDelegate
- (void)decoder:(ETDecoder *)decoder didGetPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (self.videoLayer) {
        self.videoLayer.pixelBuffer = pixelBuffer;
    }
}

- (void)setEndData:(BOOL)endData {
    _endData = endData;
    [self.h264HardDecoder setEndDataState:endData];
}

#pragma mark -- 懒加载
- (ETDecoder *)h264HardDecoder {
    if (!_h264HardDecoder) {
        _h264HardDecoder = [[ETDecoder alloc] init];
        
        _h264HardDecoder.delegate = self;
    }
    
    return _h264HardDecoder;
}

- (void)dealloc {
    if (self.videoLayer) {
        [self.videoLayer removeFromSuperlayer];
    }
}

@end
