//
//  ETVideoPacket.m
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import "ETVideoPacket.h"

@implementation ETVideoPacket
- (instancetype)initWithSize:(NSInteger)size
{
    self = [super init];
    if (self) {
        self.size = size;
    }
    
    return self;
}

- (instancetype)initWithObiect:(ETVideoPacket *)packet {
    self = [super init];
    if (self) {
        self.size = packet.size;
        self.bufferData = packet.bufferData;
    }
    
    return self;
}

@end
