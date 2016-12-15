//
//  ETMediaClient.h
//  iOSHardDecoder
//
//  Created by EthanLuo on 16/12/15.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ETDecoder.h"

typedef NS_ENUM(NSUInteger, ETPictureType) {
    ETPictureTypePNG,
    ETPictureTypeJPG,
    ETPictureTypeDefault,
};

@interface ETMediaClient : NSObject
@property (nonatomic, assign) BOOL endData;

@property (nonatomic, strong) UIView *videoView;

- (instancetype)initWithFrame:(CGRect)videFrame;

- (instancetype)initWithSuperView:(UIView *)superView;

- (void) startDecodeing;

- (void) setFrameRate:(NSInteger)frameRate;

- (void) sendFrameDataToDecodeQueue:(uint8_t *)frameBuffer length:(NSInteger)length;

- (BOOL) capturePicture:(ETPictureType) picType path:(NSString *)path;

- (void) setDisplayViewShowEnable:(BOOL)pShowDisplayView;

- (void) updateVideoFrame:(CGRect)frame;

- (void) stopDecodeing;

@end
