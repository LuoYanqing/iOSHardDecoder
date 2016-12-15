//
//  ETH264Parser.h
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ETVideoPacket.h"
typedef struct _MP4ENC_NaluUnit
{
    int type;
    long size;
    unsigned char *data;
}ETMp4EncNaluUnit;

typedef struct _MP4ENC_Metadata
{
    // video, must be h264 type
    unsigned long   nSpsLen;
    unsigned char   Sps[1024];
    unsigned long   nPpsLen;
    unsigned char   Pps[1024];
    
} ETMp4EncMetadata,*LPMP4ENC_Metadata;

@interface ETH264Parser : NSObject
+ (ETVideoPacket *)parseVideoPacket:(ETVideoPacket *)srcPacket;
+ (NSMutableArray *)packetVideoData:(uint8_t *)videoBuffer bufferLength:(NSInteger)bufferLength;
+ (bool)praseMetadataWithData:(const unsigned char*)pData withLength:(long)size withMetadata:(ETMp4EncMetadata *)metadata;
+ (long)readOneNaluWithData:(const unsigned char*)pData withLength:(long)length withOffset:(long)offset withNaluInfo:(ETMp4EncNaluUnit *)nalu;
@end
