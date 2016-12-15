//
//  ETVideoPacket.h
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ETDecoderHeader.h"
@interface ETVideoPacket : NSObject
@property (nonatomic, strong) NSData *bufferData;
@property (nonatomic, assign) NSInteger size;

- (instancetype)initWithSize:(NSInteger)size;
- (instancetype)initWithObiect:(ETVideoPacket *)packet;
@end
