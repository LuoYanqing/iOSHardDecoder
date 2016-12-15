//
//  ETDecoder.h
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>
#import "ETEAGLLayer.h"
#import "ETH264Parser.h"

@class ETDecoder;
@protocol ETDecoderDelegate <NSObject>

- (void)decoder:(ETDecoder *)decoder didGetPixelBuffer:(CVPixelBufferRef) pixelBuffer;
@optional
- (void)decoder:(ETDecoder *)decoder didFinishedPlaying:(BOOL)finish;
@end


@interface ETDecoder : NSObject

@property (nonatomic, weak) id<ETDecoderDelegate> delegate;

- (instancetype)initWithShowVideoView:(UIView*)showView;

/** 告知是否传输数据结束*/
- (void) setEndDataState:(BOOL)isEnd;

/** 开始播放*/
- (void) startDecode;

/** 设置播放帧率*/
- (void)setFrameRate:(NSInteger)frameRate;

/** 添加数据到播放队列*/
- (void) sendFrameDataToDecodeQueue:(uint8_t *)frameBuffer length:(NSInteger)length;

/**更新layer的图像*/
- (void)updateOpenglSize;

/**获取当前图像*/
- (UIImage *)currentOpenglImage;

/**设置是否OpenGL 绘图*/
- (void)setDisplayViewShowEnable:(BOOL)pShowDisplayView;

/** 停止播放*/
- (void) stopDecode;
@end
